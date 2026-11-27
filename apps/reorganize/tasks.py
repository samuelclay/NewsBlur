"""Make a reorganization proposal in the background, with live progress.

start_proposal() checks the limits in apps/reorganize/usage.py, saves a working MReorganizeProposal
holding the user's locks as they are then, and queues GenerateReorganizeProposal. The task runs
generate_proposal() from apps/reorganize/generate.py with those saved locks and stores the outcome
on the proposal.

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
from apps.reorganize.generate import INSTRUCTIONS_LIMIT
from apps.reorganize.generate import READY as GENERATED
from apps.reorganize.generate import generate_proposal
from apps.reorganize.models import (
    FAILED,
    LEVELS,
    READY,
    WORKING,
    MReorganizeLocks,
    MReorganizeProposal,
)
from newsblur_web.celeryapp import app
from utils import log as logging

STARTED = "started"
UNKNOWN_LEVEL = "unknown_level"  # the level is not one of LEVELS in apps/reorganize/models.py
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

    now = usage.clock()
    proposal_doc = MReorganizeProposal(
        user_id=user.pk,
        request_id=uuid.uuid4().hex,
        status=WORKING,
        level=level,
        find_dead=bool(find_dead),
        instructions=(instructions or "").strip()[:INSTRUCTIONS_LIMIT],
        language=language or "en",
        locks=MReorganizeLocks.for_user(user.pk),
        created_date=now,
        updated_date=now,
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
    logging.user(user, "~FBReorganize: started a ~SB%s~SN proposal" % level)
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
        )
        if outcome["code"] == GENERATED:
            run.ready(outcome)
        else:
            run.fail(outcome["code"])
    except Exception:
        run.fail(RUN_FAILED)
        raise
    logging.user(user, "~FBReorganize: ~SB%s~SN proposal %s" % (proposal_doc.level, outcome["code"]))


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

    def ready(self, outcome):
        saved = self._save(
            set__status=READY,
            set__proposal=outcome["proposal"],
            set__answer=outcome["answer"],
            set__stats=outcome["stats"],
        )
        if saved:
            self.publish("ready")

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
