"""The endpoints the web Organize sites dialog calls to make, review, revise, apply and undo a
reorganization of the user's sites and folders.

Every response is JSON. Success is {"code": 1, ...}. A refusal is {"code": -1, "reason": a machine
code}, which the dialog turns into a sentence in the reader's language, so no response carries
English text. Proposals go out as summary(), which leaves out the model's raw answer and the undo
snapshot. An id that names no proposal of the signed-in user's, or no proposal at all, is refused
with apply.NOT_FOUND.
"""

import datetime

from bson import ObjectId
from django.views.decorators.http import require_http_methods
from kombu.exceptions import OperationalError
from pymongo import ReadPreference

from apps.reader.models import UserSubscriptionFolders
from apps.reorganize import apply, decisions, tasks, usage
from apps.reorganize.models import (
    APPLIED,
    APPLYING,
    READY,
    REPLACED,
    UNDONE,
    MReorganizeLocks,
    MReorganizeProposal,
)
from apps.reorganize.plan import FolderTree
from utils import json_functions as json
from utils import log as logging
from utils.languages import normalize_language
from utils.user_functions import ajax_login_required
from utils.view_functions import is_true

INVALID_LOCKS = "invalid_locks"  # a lock path is not a list of folder names
INVALID_DECISIONS = "invalid_decisions"  # the decisions are not a JSON object

# Statuses whose summary carries the proposal and the decisions made on it.
REVIEWED_STATUSES = (READY, REPLACED, APPLYING, APPLIED, UNDONE)
APPLIED_STATUSES = (APPLYING, APPLIED, UNDONE)


@ajax_login_required
@require_http_methods(["GET"])
@json.json_view
def status(request):
    """Everything the dialog needs to open: the limits, the locks, and the current proposal."""
    user = request.user
    # Read first, since usage.limits() fails a run left working too long and current() should show it so.
    limits = _limits(user)
    current = MReorganizeProposal.current(user.pk)
    return {
        "code": 1,
        "limits": limits,
        "locks": MReorganizeLocks.for_user(user.pk),
        "proposal": summary(user, current) if current else None,
    }


@ajax_login_required
@require_http_methods(["POST"])
@json.json_view
def save_locks(request):
    """Replace the user's locks with `keep` and `skip`, each a JSON list of folder paths.

    A path that names no folder the user has is dropped. Anything else that is not a list of
    folder names refuses the whole request.
    """
    user = request.user
    keep = _lock_paths(request.POST.get("keep"))
    skip = _lock_paths(request.POST.get("skip"))
    if keep is None or skip is None:
        return {"code": -1, "reason": INVALID_LOCKS}

    paths = list(FolderTree.from_list(_stored_folders(user)).folder_keys().values())
    MReorganizeLocks.save_locks(
        user.pk,
        keep=[path for path in keep if path in paths],
        skip=[path for path in skip if path in paths],
    )
    locks = MReorganizeLocks.for_user(user.pk)
    logging.user(
        request,
        "~FBReorganize: locked ~SB%s~SN kept and ~SB%s~SN skipped folders"
        % (len(locks["keep"]), len(locks["skip"])),
    )
    return {"code": 1, "locks": locks}


@ajax_login_required
@require_http_methods(["POST"])
@json.json_view
def propose(request):
    """Start a proposal at `level`, finding dead sites when `find_dead`, with the user's `instructions`."""
    user = request.user
    try:
        started = tasks.start_proposal(
            user,
            request.POST.get("level"),
            is_true(request.POST.get("find_dead")),
            request.POST.get("instructions", ""),
            _interface_language(request),
        )
    except OperationalError:
        return {"code": -1, "reason": tasks.RUN_FAILED, "limits": _limits(user)}
    return _started_response(user, started)


@ajax_login_required
@require_http_methods(["POST"])
@json.json_view
def save_decisions(request):
    """Merge `decisions`, a JSON object of only what changed, into a ready proposal's decisions."""
    proposal_doc = _users_proposal(request)
    if proposal_doc is None:
        return {"code": -1, "reason": apply.NOT_FOUND}
    try:
        changes = json.decode(request.POST.get("decisions") or "")
    except ValueError:
        changes = None
    if not isinstance(changes, dict):
        return {"code": -1, "reason": INVALID_DECISIONS}
    refusal = tasks.ready_refusal(proposal_doc)
    if refusal:
        return {"code": -1, "reason": refusal}

    before = decisions.merge_decisions(proposal_doc.decisions, {}, proposal_doc.proposal)
    after = decisions.merge_decisions(proposal_doc.decisions, changes, proposal_doc.proposal)
    if not MReorganizeProposal.change_decisions(proposal_doc.id, before, after):
        proposal_doc.reload()
        return {"code": -1, "reason": tasks.ready_refusal(proposal_doc) or apply.NOT_READY}
    proposal_doc.reload()
    return {"code": 1, "decisions": _decisions(proposal_doc)}


@ajax_login_required
@require_http_methods(["POST"])
@json.json_view
def revise(request):
    """Start a revision of a ready proposal as `request`, the user's own words, asks."""
    user = request.user
    proposal_doc = _users_proposal(request)
    if proposal_doc is None:
        return {"code": -1, "reason": apply.NOT_FOUND}
    try:
        started = tasks.start_revision(user, proposal_doc, request.POST.get("request", ""))
    except OperationalError:
        return {"code": -1, "reason": tasks.RUN_FAILED, "limits": _limits(user)}
    return _started_response(user, started)


@ajax_login_required
@require_http_methods(["POST"])
@json.json_view
def apply_proposal(request):
    """Apply a ready proposal with its stored decisions."""
    user = request.user
    proposal_doc = _users_proposal(request)
    if proposal_doc is None:
        return {"code": -1, "reason": apply.NOT_FOUND}
    if proposal_doc.status == REPLACED:
        return {"code": -1, "reason": REPLACED}

    applied = apply.apply_proposal(user, proposal_doc)
    if applied["code"] != apply.APPLIED_CODE:
        return {"code": -1, "reason": applied["code"], "limits": _limits(user)}
    proposal_doc.reload()
    logging.user(request, "~FBReorganize: applied a ~SB%s~SN proposal" % proposal_doc.level)
    return {
        "code": 1,
        "proposal": summary(user, proposal_doc),
        "folders": applied["folders"],
        "limits": _limits(user),
    }


@ajax_login_required
@require_http_methods(["POST"])
@json.json_view
def undo_proposal(request):
    """Put back what an applied proposal changed."""
    user = request.user
    proposal_doc = _users_proposal(request)
    if proposal_doc is None:
        return {"code": -1, "reason": apply.NOT_FOUND}

    undone = apply.undo_proposal(user, proposal_doc)
    if undone["code"] != apply.UNDONE_CODE:
        return {"code": -1, "reason": undone["code"]}
    proposal_doc.reload()
    logging.user(request, "~FBReorganize: undid a ~SB%s~SN proposal" % proposal_doc.level)
    return {"code": 1, "proposal": summary(user, proposal_doc), "folders": undone["folders"]}


def summary(user, proposal_doc):
    """What the dialog shows of one proposal. Site titles and icons are left out, since the web
    client already has every subscription by feed id."""
    can_undo = proposal_doc.status in (APPLYING, APPLIED) and apply.undo_refusal(user, proposal_doc) is None
    data = {
        "id": str(proposal_doc.id),
        "status": proposal_doc.status,
        "level": proposal_doc.level,
        "find_dead": bool(proposal_doc.find_dead),
        "instructions": proposal_doc.instructions or "",
        "progress": proposal_doc.progress or None,
        "error": proposal_doc.error or None,
        "created_date": _iso(proposal_doc.created_date),
        "request_id": proposal_doc.request_id,
        "revises": str(proposal_doc.revises) if proposal_doc.revises else None,
        "revision_request": proposal_doc.revision_request or None,
        "revisions_left": max(0, usage.revision_limit(user) - (proposal_doc.revisions or 0)),
        "sites": (proposal_doc.stats or {}).get("sites"),
        "can_undo": can_undo,
        "undo_until": None,
    }
    if proposal_doc.status in REVIEWED_STATUSES:
        data["proposal"] = proposal_doc.proposal
        data["decisions"] = _decisions(proposal_doc)
    if proposal_doc.status in APPLIED_STATUSES:
        data["result"] = proposal_doc.result or None
        data["applied_date"] = _iso(proposal_doc.applied_date)
        if can_undo:
            data["undo_until"] = _iso(proposal_doc.applied_date + datetime.timedelta(days=apply.UNDO_DAYS))
    return data


def _started_response(user, started):
    if started["code"] != tasks.STARTED:
        return {"code": -1, "reason": started["code"], "limits": _limits(user)}
    return {"code": 1, "proposal": summary(user, started["proposal"]), "limits": _limits(user)}


def _users_proposal(request):
    """The signed-in user's proposal named by `proposal_id`, or None."""
    proposal_id = request.POST.get("proposal_id") or ""
    if not ObjectId.is_valid(proposal_id):
        return None
    return (
        MReorganizeProposal.objects(id=proposal_id, user_id=request.user.pk)
        .read_preference(ReadPreference.PRIMARY)
        .first()
    )


def _decisions(proposal_doc):
    """The stored decisions in all three sections, holding only choices about the proposal's items."""
    return decisions.merge_decisions(proposal_doc.decisions, {}, proposal_doc.proposal)


def _lock_paths(value):
    """The folder paths in a JSON list, or None unless every path is a list of non-empty names."""
    try:
        paths = json.decode(value or "[]")
    except ValueError:
        return None
    if not isinstance(paths, list):
        return None
    for path in paths:
        if not (isinstance(path, list) and path and all(isinstance(name, str) and name for name in path)):
            return None
    return paths


def _limits(user):
    limits = usage.limits(user)
    return dict(limits, next_date=_iso(limits["next_date"]))


def _interface_language(request):
    """The language the reader's interface is in, which apps/profile/language.py resolves on every
    request from their choice or their browser."""
    language = normalize_language(getattr(request, "LANGUAGE_CODE", None))
    return language if language and language != "auto" else "en"


def _stored_folders(user):
    folders = UserSubscriptionFolders.objects.filter(user=user).values_list("folders", flat=True).first()
    if not folders:
        return []
    return json.decode(folders)


def _iso(moment):
    """A naive UTC date as ISO 8601 with its time zone, which every browser parses the same way."""
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ") if moment else None
