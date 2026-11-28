"""Make a reorganization proposal in the background, with live progress.

start_proposal() checks the limits in apps/reorganize/usage.py, saves a working MReorganizeProposal
holding the user's locks as they are then, and queues GenerateReorganizeProposal. The task runs
generate_proposal() from apps/reorganize/generate.py with those saved locks and stores the outcome
on the proposal.

start_revision() makes a ready proposal again as the user asks, the same way. Once the revision is
ready it holds the decisions apps/reorganize/decisions.py carries over, and the proposal it revises
is replaced. A revision that fails leaves that proposal as it was.

Progress is saved on the proposal for clients that poll, and each event is published on the user's
channel as "reorganize:" + JSON, which node/reorganize.coffee relays to the web client. The events
are start, progress (step, done, total), ready and error (code), and each carries the run's
request_id and proposal_id. The ready event leaves the proposal out, since it can be large; the
client fetches it.
"""

import json
import uuid

import redis
from django.conf import settings
from django.contrib.auth.models import User
from kombu.exceptions import OperationalError
from pymongo import ReadPreference

from apps.reorganize import usage
from apps.reorganize.apply import ALREADY_APPLIED, NOT_FOUND, NOT_READY
from apps.reorganize.decisions import carry_decisions
from apps.reorganize.generate import INSTRUCTIONS_LIMIT
from apps.reorganize.generate import READY as GENERATED
from apps.reorganize.generate import generate_proposal
from apps.reorganize.models import (
    FAILED,
    LEVELS,
    READY,
    REPLACED,
    WORKING,
    MReorganizeLocks,
    MReorganizeProposal,
)
from newsblur_web.celeryapp import app
from utils import log as logging

STARTED = "started"
UNKNOWN_LEVEL = "unknown_level"  # the level is not one of LEVELS in apps/reorganize/models.py
EMPTY_REQUEST = "empty_request"  # a revision was asked for without saying what to change
REVISION_LIMIT = "revision_limit"  # the proposal has had usage.revision_limit() revisions in a row
# The error stored on a run that raised, or could not be queued.
RUN_FAILED = "run_failed"

# usage.STALE_AFTER sits well above this, so a run past it is known to have stopped.
TIME_LIMIT = 15 * 60
SOFT_TIME_LIMIT = TIME_LIMIT - 30

EVENT_PREFIX = "reorganize:"


def start_proposal(user, level, find_dead, instructions, language):
    """Start making a proposal for `user` in the background.

    Returns {"code": STARTED, "proposal": the new working MReorganizeProposal}, or a refusal that
    starts nothing: {"code": UNKNOWN_LEVEL}, or {"code": a refusal from usage.can_start(),
    "next_date"}. A run that cannot be queued is failed, and the error raised.
    """
    if level not in LEVELS:
        return {"code": UNKNOWN_LEVEL}
    verdict = usage.can_start(user)
    if not verdict["allowed"]:
        return {"code": verdict["code"], "next_date": verdict["next_date"]}
    return _start(
        user,
        level=level,
        find_dead=bool(find_dead),
        instructions=(instructions or "").strip()[:INSTRUCTIONS_LIMIT],
        language=language or "en",
    )


def start_revision(user, proposal_doc, request):
    """Start revising `proposal_doc`, a ready proposal of `user`'s, as the user's `request` asks.

    The revision is a new working proposal with the same level, dead site search, instructions and
    language, and the user's locks as they are now. Returns {"code": STARTED, "proposal": it}, or a
    refusal that starts nothing: {"code": NOT_FOUND, NOT_READY, ALREADY_APPLIED, REPLACED,
    REVISION_LIMIT, EMPTY_REQUEST or a refusal from usage.can_start(), "next_date"}. A revision that
    cannot be queued is failed, and the error raised.
    """
    request = (request or "").strip()[:INSTRUCTIONS_LIMIT]
    refusal = _revision_refusal(user, proposal_doc, request)
    if refusal:
        return {"code": refusal, "next_date": None}
    verdict = usage.can_start(user, revision=True)
    if not verdict["allowed"]:
        return {"code": verdict["code"], "next_date": verdict["next_date"]}
    return _start(
        user,
        level=proposal_doc.level,
        find_dead=proposal_doc.find_dead,
        instructions=proposal_doc.instructions,
        language=proposal_doc.language,
        revises=proposal_doc.id,
        revision_request=request,
        revisions=(proposal_doc.revisions or 0) + 1,
    )


def ready_refusal(proposal_doc):
    """Why `proposal_doc` cannot be decided on or revised now, or None while it is ready."""
    if proposal_doc.status == READY:
        return None
    if proposal_doc.status == REPLACED:
        return REPLACED
    if proposal_doc.status in (WORKING, FAILED):
        return NOT_READY
    return ALREADY_APPLIED


def _revision_refusal(user, proposal_doc, request):
    if proposal_doc.user_id != user.pk:
        return NOT_FOUND
    refusal = ready_refusal(proposal_doc)
    if refusal:
        return refusal
    if (proposal_doc.revisions or 0) >= usage.revision_limit(user):
        return REVISION_LIMIT
    if not request:
        return EMPTY_REQUEST
    return None


def _start(user, **fields):
    """Save a working proposal with `fields` and queue its run, unless another run is working."""
    now = usage.clock()
    proposal_doc = MReorganizeProposal(
        user_id=user.pk,
        request_id=uuid.uuid4().hex,
        status=WORKING,
        locks=MReorganizeLocks.for_user(user.pk),
        created_date=now,
        updated_date=now,
        **fields,
    )
    proposal_doc.save()
    if not _first_working(proposal_doc):
        proposal_doc.delete()
        return {"code": usage.ALREADY_RUNNING, "next_date": None}

    try:
        GenerateReorganizeProposal.apply_async(
            kwargs={"proposal_id": str(proposal_doc.id)},
            queue="work_queue",
        )
    except OperationalError:
        _Run(user, proposal_doc).fail(RUN_FAILED)
        raise
    kind = "revision" if proposal_doc.revises else "proposal"
    logging.user(user, "~FBReorganize: started a ~SB%s~SN %s" % (proposal_doc.level, kind))
    return {"code": STARTED, "proposal": proposal_doc}


@app.task(name="generate-reorganize-proposal", time_limit=TIME_LIMIT, soft_time_limit=SOFT_TIME_LIMIT)
def GenerateReorganizeProposal(proposal_id):
    """Make the proposal for a working MReorganizeProposal and store the outcome on it."""
    proposal_doc = (
        MReorganizeProposal.objects(id=proposal_id, status=WORKING)
        .read_preference(ReadPreference.PRIMARY)
        .first()
    )
    if proposal_doc is None:
        # apps/reorganize/usage.py failed it as stale before the task reached it.
        return

    user = User.objects.get(pk=proposal_doc.user_id)
    revised = _revised(proposal_doc)
    revision = None
    if proposal_doc.revises:
        revision = {
            "answer": revised.answer if revised else {},
            "request": proposal_doc.revision_request,
        }
    run = _Run(user, proposal_doc)
    run.publish("start")
    try:
        outcome = generate_proposal(
            user,
            proposal_doc.level,
            proposal_doc.find_dead,
            proposal_doc.instructions,
            proposal_doc.locks,
            language=proposal_doc.language or "en",
            progress=run.progress,
            revision=revision,
        )
        if outcome["code"] == GENERATED:
            run.ready(outcome, revised)
        else:
            run.fail(outcome["code"])
    except Exception:
        run.fail(RUN_FAILED)
        raise
    logging.user(user, "~FBReorganize: ~SB%s~SN proposal %s" % (proposal_doc.level, outcome["code"]))


def _revised(proposal_doc):
    """The proposal `proposal_doc` revises, or None for a first proposal."""
    if not proposal_doc.revises:
        return None
    return (
        MReorganizeProposal.objects(id=proposal_doc.revises, user_id=proposal_doc.user_id)
        .read_preference(ReadPreference.PRIMARY)
        .first()
    )


def _first_working(proposal_doc):
    """Whether `proposal_doc` is the user's only working run, or the first of several started at
    once. Every start compares the same ids, so exactly one of them goes ahead."""
    first = (
        MReorganizeProposal.objects(user_id=proposal_doc.user_id, status=WORKING)
        .read_preference(ReadPreference.PRIMARY)
        .order_by("id")
        .only("id")
        .first()
    )
    return first is not None and first.id == proposal_doc.id


class _Run:
    """Saves one run's progress and outcome on its proposal and publishes them on the user's channel.

    Each save applies only while the proposal is still working, so a run that usage.py failed as
    stale stays failed and publishes nothing more.
    """

    def __init__(self, user, proposal_doc):
        self.user = user
        self.proposal_doc = proposal_doc

    def progress(self, step, done, total):
        self._save(set__progress={"step": step, "done": done, "total": total})
        self.publish("progress", step=step, done=done, total=total)

    def ready(self, outcome, revised=None):
        """Store a finished proposal. For a revision, the proposal it revises is replaced first, and a
        revision whose proposal stopped being ready while it worked fails instead."""
        decisions = {}
        if revised is not None:
            revised.reload()
            decisions = carry_decisions(revised.proposal, revised.decisions, outcome["proposal"])
            if not _replace(revised):
                revised.reload()
                self.fail(ready_refusal(revised) or ALREADY_APPLIED)
                return

        saved = self._save(
            set__status=READY,
            set__proposal=outcome["proposal"],
            set__answer=outcome["answer"],
            set__stats=outcome["stats"],
            set__decisions=decisions,
        )
        if saved:
            self.publish("ready")
        elif revised is not None:
            _restore(revised)

    def fail(self, code):
        if self._save(set__status=FAILED, set__error=code):
            self.publish("error", code=code)

    def publish(self, event_type, **fields):
        """Publish one event. A publish that fails is logged, and the run goes on."""
        payload = {
            "type": event_type,
            "request_id": self.proposal_doc.request_id,
            "proposal_id": str(self.proposal_doc.id),
            **fields,
        }
        try:
            redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL).publish(
                self.user.username, EVENT_PREFIX + json.dumps(payload, ensure_ascii=False)
            )
        except redis.RedisError as error:
            logging.user(
                self.user,
                "~FBReorganize: ~FRcould not publish ~SB%s~SN: %s" % (event_type, type(error).__name__),
            )

    def _save(self, **updates):
        """Save `updates` on the proposal if it is still working. Returns whether it was."""
        saved = MReorganizeProposal.objects(id=self.proposal_doc.id, status=WORKING).update_one(
            set__updated_date=usage.clock(), **updates
        )
        return saved == 1


def _replace(proposal_doc):
    """Mark a ready proposal replaced by its revision. False if it is no longer ready."""
    replaced = MReorganizeProposal.objects(id=proposal_doc.id, status=READY).update_one(
        set__status=REPLACED, set__updated_date=usage.clock()
    )
    return replaced == 1


def _restore(proposal_doc):
    """Make a proposal ready again after the revision that replaced it could not be stored."""
    MReorganizeProposal.objects(id=proposal_doc.id, status=REPLACED).update_one(
        set__status=READY, set__updated_date=usage.clock()
    )
