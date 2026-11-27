"""Ask the model for a reorganization of a user's sites and folders, and turn its answer into a proposal.

generate_proposal() shows the model only what model_view() in apps/reorganize/derive.py allows,
described by apps/reorganize/sites.py. Unless the level is "tidy", which files sites into the folders
the user already has, a design call first decides the folders. Assign calls then file the sites into
them, ASSIGN_BATCH_SIZE at a time. derive.build_proposal() turns the answer, with the dead sites
sites.py finds by rule, into a proposal for apps/reorganize/plan.py.

A revision runs the same way, and every call is told what the reader asks to change. The design
call also sees the targets it designed before and changes them only as far as the request needs.

Every outcome is a return value: {"code": READY, ...} or {"code": one of the failure codes below}.
"""

import json

import anthropic
from django.conf import settings

from apps.ask_ai.providers import AnthropicProvider
from apps.reader.models import UserSubscriptionFolders
from apps.reorganize import prompts
from apps.reorganize.derive import build_proposal, model_view
from apps.reorganize.plan import ROOT_KEY, clean_folder_name
from apps.reorganize.sites import dead_sites, folder_label, gather_sites
from utils import log as logging
from utils.llm_costs import LLMCostTracker
from utils.llm_models import ANTHROPIC_CHAT_MODEL

READY = "ready"
NO_API_KEY = "no_api_key"  # no Anthropic key is configured, so the model was never called
NOTHING_TO_ORGANIZE = "nothing_to_organize"  # no site the model may see, or no folder to file into
MODEL_DECLINED = "model_declined"  # the model declined or ran out of room before answering
MODEL_FAILED = "model_failed"  # the call failed, or the answer was not in the expected shape

ASSIGN_BATCH_SIZE = 80
DESIGN_SITE_LIMIT = 2000
INSTRUCTIONS_LIMIT = 4000
MAX_TOKENS = 16000
DESIGN_EFFORT = "high"
ASSIGN_EFFORT = "low"

# A refusal and a max_tokens stop both leave no usable answer.
DECLINED_STOP_REASONS = ("refusal", "max_tokens")
# The stop reason call_model() reports when the request itself failed.
ERROR_STOP_REASON = "error"
# A declined request is retried on a fallback model the API picks for the kind of decline.
FALLBACK_BETA = "server-side-fallback-2026-07-01"

# Incoming newsletters are filed into a top-level folder of exactly this name, which apps/newsletters/
# models.py creates when it is missing, so the model never renames, nests or merges it away.
NEWSLETTERS_FOLDER = "Newsletters"
NEWSLETTERS_TARGET_ID = "newsletters"

COST_FEATURE = "reorganize"


def generate_proposal(
    user, level, find_dead, instructions, locks, language="en", progress=None, model_call=None, revision=None
):
    """Ask the model to reorganize `user`'s sites and folders at `level` and return its proposal.

    `level` is "tidy", "reorganize" or "fresh". `locks` is {"keep": [...], "skip": [...]} as
    apps/reorganize/plan.py takes it. `progress(step, done, total)`, when given, is called as the work
    goes, with `done` rising to `total`. `model_call(system, content, schema, effort)` is call_model()
    unless a caller passes its own. `revision`, for a revision of an earlier proposal, is
    {"answer": the earlier run's answer, "request": what the reader asks to change}.

    Returns {"code": READY, "proposal", "answer": {"targets", "assignments", "folders"}, "stats"},
    where the targets and assignments are what build_proposal() was given and "folders" maps each
    folder key they could name to its path, or {"code": NO_API_KEY | NOTHING_TO_ORGANIZE |
    MODEL_DECLINED | MODEL_FAILED}.
    """
    if not AnthropicProvider().is_configured():
        return {"code": NO_API_KEY}
    tidy = level == "tidy"
    instructions = (instructions or "").strip()[:INSTRUCTIONS_LIMIT]
    request = ((revision or {}).get("request") or "").strip()[:INSTRUCTIONS_LIMIT] or None

    folders = _stored_folders(user)
    view = model_view(folders, locks)
    sites = gather_sites(user.pk, view)
    files_sites = not tidy or bool(view["folders"])
    if not sites or not (files_sites or find_dead):
        return {"code": NOTHING_TO_ORGANIZE}

    batches = _batches(sites, ASSIGN_BATCH_SIZE) if files_sites else []
    run = _Run(user, model_call or call_model, progress, total=2 + (0 if tidy else 1) + len(batches))
    run.report("sites")

    targets = []
    if tidy:
        destinations = [
            {"id": folder["key"], "path": folder_label(folder["path"])} for folder in view["folders"]
        ]
    else:
        shown = _even_sample(sites, DESIGN_SITE_LIMIT)
        earlier_targets = _earlier_targets(revision.get("answer"), view) if revision else None
        result = run.call(
            prompts.design_system(level, instructions, language, request),
            prompts.design_content(
                view["folders"], [site.line() for site in shown], len(sites), earlier_targets
            ),
            prompts.DESIGN_SCHEMA,
            DESIGN_EFFORT,
        )
        failure, targets = _answer_entries(result, "targets")
        if failure:
            run.record_cost()
            return {"code": failure}
        targets = pin_newsletters(targets, view)
        destinations = _target_destinations(targets, view)
        run.report("design")

    assignments, failures = [], []
    system = prompts.assign_system(tidy, destinations, instructions, language, request)
    for batch in batches:
        result = run.call(
            system,
            prompts.assign_content([site.digest() for site in batch]),
            prompts.ASSIGN_SCHEMA,
            ASSIGN_EFFORT,
        )
        failure, entries = _answer_entries(result, "assignments")
        if failure:
            failures.append(failure)
        else:
            batch_ids = {site.feed_id for site in batch}
            assignments += [entry for entry in entries if _files_into_a_folder(entry, batch_ids)]
        run.report("assign")
    if len(failures) * 2 > len(batches):
        run.record_cost()
        return {"code": MODEL_DECLINED if set(failures) == {MODEL_DECLINED} else MODEL_FAILED}

    dead = dead_sites(sites) if find_dead else []
    proposal = build_proposal(folders, locks, targets, assignments, dead, allow_folder_changes=not tidy)
    run.report("proposal")
    run.record_cost()
    return {
        "code": READY,
        "proposal": proposal,
        "answer": {
            "targets": targets,
            "assignments": assignments,
            "folders": {folder["key"]: folder["path"] for folder in view["folders"]},
        },
        "stats": {
            "sites": len(sites),
            "design_sites": None if tidy else min(len(sites), DESIGN_SITE_LIMIT),
            "batches": len(batches),
            "skipped_batches": len(failures),
            "input_tokens": run.input_tokens,
            "output_tokens": run.output_tokens,
        },
    }


def pin_newsletters(targets, view):
    """`targets` with the open top-level Newsletters folder kept where and as it is.

    The target that is that folder (one named Newsletters at the top level, or else the first whose
    first open continues key is the folder) keeps the folder under its own name at the top level,
    and every other target loses the folder's key. With no such target, one is added. Sites still
    move in and out of the folder as the assignments say.
    """
    key = next((folder["key"] for folder in view["folders"] if folder["path"] == [NEWSLETTERS_FOLDER]), None)
    if key is None:
        return targets

    open_keys = {folder["key"] for folder in view["folders"]}
    entries = [dict(entry) for entry in targets if isinstance(entry, dict)]
    for entry in entries:
        if not isinstance(entry.get("continues"), list):
            entry["continues"] = []
    named = [
        entry
        for entry in entries
        if entry.get("parent") is None
        and (clean_folder_name(entry.get("name")) or "").lower() == "newsletters"
    ]
    continuing = [
        entry
        for entry in entries
        if [other for other in entry["continues"] if other in open_keys][:1] == [key]
    ]
    pinned = (named + continuing + [None])[0]

    for entry in entries:
        entry["continues"] = [other for other in entry["continues"] if other != key]
    if pinned is None:
        used_ids = {entry.get("id") for entry in entries}
        pinned = {"id": NEWSLETTERS_TARGET_ID, "reason": ""}
        while pinned["id"] in used_ids:
            pinned["id"] += "_"
        entries.append(pinned)
    pinned.update(name=NEWSLETTERS_FOLDER, parent=None, continues=[key] + pinned.get("continues", []))
    return entries


def _earlier_targets(answer, view):
    """The targets of an earlier run's `answer`, each "continues" key turned into the key the same
    folder has now. The keys follow the tree's order, so a folder added or removed since moves them;
    a folder that is gone or locked now drops out."""
    answer = answer if isinstance(answer, dict) else {}
    earlier_paths = answer.get("folders") if isinstance(answer.get("folders"), dict) else {}
    keys_now = {tuple(folder["path"]): folder["key"] for folder in view["folders"]}
    targets = answer.get("targets") if isinstance(answer.get("targets"), list) else []

    earlier = []
    for entry in targets:
        if not isinstance(entry, dict):
            continue
        continues = entry.get("continues") if isinstance(entry.get("continues"), list) else []
        paths = [earlier_paths.get(key) for key in continues if isinstance(key, str)]
        earlier.append(
            {
                "id": entry.get("id"),
                "name": entry.get("name"),
                "parent": entry.get("parent"),
                "continues": [
                    keys_now[tuple(path)]
                    for path in paths
                    if isinstance(path, list) and tuple(path) in keys_now
                ],
                "reason": entry.get("reason"),
            }
        )
    return earlier


def call_model(system, content, schema, effort):
    """One request to ANTHROPIC_CHAT_MODEL whose answer is JSON matching `schema`.

    Returns {"data": the answer as a dict, or None, "stop_reason", "input_tokens", "output_tokens"}.
    A failed request has stop_reason ERROR_STOP_REASON. A declined or cut off one has no data; a
    partial answer is never parsed. The SDK retries rate limits and server errors on its own.
    """
    client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
    try:
        response = client.messages.create(
            model=ANTHROPIC_CHAT_MODEL,
            max_tokens=MAX_TOKENS,
            system=system,
            messages=[{"role": "user", "content": content}],
            # anthropic 0.75 has no output_config or fallbacks parameters, so they go in the body.
            extra_headers={"anthropic-beta": FALLBACK_BETA},
            extra_body={
                "output_config": {"effort": effort, "format": {"type": "json_schema", "schema": schema}},
                "fallbacks": "default",
            },
        )
    except anthropic.APIStatusError as error:
        logging.error(" ---> ~FRReorganize model call failed with status %s" % error.status_code)
        return {"data": None, "stop_reason": ERROR_STOP_REASON, "input_tokens": 0, "output_tokens": 0}
    except anthropic.APIError as error:
        logging.error(" ---> ~FRReorganize model call failed: %s" % type(error).__name__)
        return {"data": None, "stop_reason": ERROR_STOP_REASON, "input_tokens": 0, "output_tokens": 0}

    input_tokens, output_tokens = _usage_tokens(response.usage)
    result = {
        "data": None,
        "stop_reason": response.stop_reason,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
    }
    if response.stop_reason in DECLINED_STOP_REASONS:
        details = getattr(response, "stop_details", None)
        category = (
            details.get("category") if isinstance(details, dict) else getattr(details, "category", None)
        )
        logging.info(" ---> ~FYReorganize model call stopped: %s (%s)" % (response.stop_reason, category))
        return result

    text = next(
        (
            block.text
            for block in response.content
            if getattr(block, "type", None) == "text" and isinstance(getattr(block, "text", None), str)
        ),
        None,
    )
    try:
        data = json.loads(text) if text is not None else None
    except ValueError:
        data = None
    result["data"] = data if isinstance(data, dict) else None
    return result


class _Run:
    """The model calls of one generate_proposal() run: their summed tokens and the progress reports."""

    def __init__(self, user, model_call, progress, total):
        self.user = user
        self.model_call = model_call
        self.progress = progress
        self.total = total
        self.done = 0
        self.calls = 0
        self.input_tokens = 0
        self.output_tokens = 0

    def call(self, system, content, schema, effort):
        result = self.model_call(system, content, schema, effort)
        self.calls += 1
        self.input_tokens += _token_count(result.get("input_tokens"))
        self.output_tokens += _token_count(result.get("output_tokens"))
        return result

    def report(self, step):
        self.done += 1
        if self.progress:
            self.progress(step, self.done, self.total)

    def record_cost(self):
        if not self.calls:
            return
        LLMCostTracker.record_usage(
            provider="anthropic",
            model=ANTHROPIC_CHAT_MODEL,
            feature=COST_FEATURE,
            input_tokens=self.input_tokens,
            output_tokens=self.output_tokens,
            user_id=self.user.pk,
            metadata={"calls": self.calls},
        )


def _answer_entries(result, key):
    """(failure code or None, the answer's list under `key`) for one model_call result."""
    if result.get("stop_reason") in DECLINED_STOP_REASONS:
        return MODEL_DECLINED, None
    data = result.get("data")
    entries = data.get(key) if isinstance(data, dict) else None
    if not isinstance(entries, list):
        return MODEL_FAILED, None
    return None, entries


def _files_into_a_folder(entry, batch_ids):
    """Whether an assignment names a site of its batch and a folder. A proposal never moves a site
    out to the top level, so an assignment to it is dropped."""
    return isinstance(entry, dict) and entry.get("feed_id") in batch_ids and entry.get("folder") != ROOT_KEY


def _target_destinations(targets, view):
    """The folders an assign call may file into: each target with its path and the current folders
    it carries on."""
    paths = {folder["key"]: folder["path"] for folder in view["folders"]}
    by_id = {}
    for entry in targets:
        if isinstance(entry, dict) and isinstance(entry.get("id"), str) and entry["id"] != ROOT_KEY:
            by_id.setdefault(entry["id"], entry)

    def continued(entry):
        keys = entry.get("continues") if isinstance(entry.get("continues"), list) else []
        return [key for key in keys if isinstance(key, str) and key in paths]

    def name(entry):
        keys = continued(entry)
        return clean_folder_name(entry.get("name")) or (paths[keys[0]][-1] if keys else None)

    def path(target_id):
        names, seen = [], set()
        while target_id in by_id and target_id not in seen:
            seen.add(target_id)
            names.insert(0, name(by_id[target_id]) or target_id)
            target_id = by_id[target_id].get("parent")
        return names

    destinations = []
    for target_id, entry in by_id.items():
        if name(entry) is None:
            continue
        destinations.append(
            {
                "id": target_id,
                "path": folder_label(path(target_id)),
                "continues": [folder_label(paths[key]) for key in continued(entry)],
            }
        )
    return destinations


def _batches(items, size):
    """`items` in order, in lists of `size` and a shorter last one."""
    batches = []
    for start in range(0, len(items), size):
        end = start + size
        batches.append(items[start:end])
    return batches


def _even_sample(items, limit):
    """`limit` of `items` spread evenly across them, in their order, or all of them if they fit."""
    if len(items) <= limit:
        return items
    return [items[index * len(items) // limit] for index in range(limit)]


def _stored_folders(user):
    folders = UserSubscriptionFolders.objects.filter(user=user).values_list("folders", flat=True).first()
    return json.loads(folders) if folders else []


def _usage_tokens(usage):
    """(input tokens, output tokens) of a response. With a fallback, `iterations` lists every attempt,
    and the top-level counts cover only the last. Cached input tokens count as input."""
    attempts = getattr(usage, "iterations", None)
    entries = attempts if isinstance(attempts, list) and attempts else [usage]
    input_tokens = output_tokens = 0
    for entry in entries:
        for field in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"):
            input_tokens += _token_count(_field(entry, field))
        output_tokens += _token_count(_field(entry, "output_tokens"))
    return input_tokens, output_tokens


def _field(entry, name):
    return entry.get(name) if isinstance(entry, dict) else getattr(entry, name, None)


def _token_count(value):
    return value if isinstance(value, int) and not isinstance(value, bool) and value > 0 else 0
