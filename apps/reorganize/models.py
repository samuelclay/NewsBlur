"""Stored reorganization proposals and the folder locks a user sets for them.

A proposal is made in the background, reviewed in the web Organize sites dialog, then applied and
possibly undone by apps/reorganize/apply.py. `proposal`, `decisions` and `locks` hold the shapes
apps/reorganize/plan.py takes. Both documents load with "strict": False so a release that adds a
field never breaks one still reading the documents.
"""

import datetime

import mongoengine as mongo
from mongoengine.queryset.visitor import Q
from pymongo import ReadPreference

WORKING = "working"  # the model is still building the proposal
READY = "ready"  # waiting for the user's decisions
FAILED = "failed"  # no proposal could be made; `error` says why
APPLYING = "applying"  # the undo snapshot is saved and the apply has started
APPLIED = "applied"
UNDONE = "undone"
REPLACED = "replaced"  # a revision of it became ready, so it can no longer be decided on or applied
STATUSES = (WORKING, READY, FAILED, APPLYING, APPLIED, UNDONE, REPLACED)

LEVELS = ("tidy", "reorganize", "fresh")


class MReorganizeProposal(mongo.Document):
    """One request to reorganize a user's sites and folders, from the model's answer to its undo.

    apps/reorganize/tasks.py makes the proposal. While it works, `progress` is {"step", "done",
    "total"}. Once ready, `answer` is the model's answer and `stats` what generate_proposal() in
    apps/reorganize/generate.py counted. `applied_date` is when the apply started. `result` counts
    what the apply did and lists the items plan.py skipped. `undo` is {"folders": the stored tree
    before, as its JSON text, "carried": what apps/reorganize/state.py moved, "muted_feed_ids": the
    sites the apply muted}.

    A revision is a proposal made again from an earlier one at the user's request: `revises` is the
    earlier proposal's id, `revision_request` what the user asked to change, and `revisions` how
    many revisions lead back to the first proposal.
    """

    user_id = mongo.IntField(required=True)
    request_id = mongo.StringField()
    status = mongo.StringField(choices=STATUSES, default=WORKING)
    level = mongo.StringField(choices=LEVELS)
    find_dead = mongo.BooleanField(default=False)
    instructions = mongo.StringField()
    language = mongo.StringField()
    locks = mongo.DictField()
    progress = mongo.DictField()
    proposal = mongo.DictField()
    answer = mongo.DictField()
    stats = mongo.DictField()
    decisions = mongo.DictField()
    revisions = mongo.IntField(default=0)
    revises = mongo.ObjectIdField()
    revision_request = mongo.StringField()
    error = mongo.StringField()
    created_date = mongo.DateTimeField(default=datetime.datetime.now)
    updated_date = mongo.DateTimeField(default=datetime.datetime.now)
    applied_date = mongo.DateTimeField()
    undone_date = mongo.DateTimeField()
    result = mongo.DictField()
    undo = mongo.DictField()

    meta = {
        "collection": "reorganize_proposals",
        "indexes": [{"fields": ["user_id", "-created_date"]}],
        "allow_inheritance": False,
        "strict": False,
    }

    @classmethod
    def last_applied(cls, user_id):
        """The user's proposal whose apply started last, of those applied or still applying."""
        return (
            cls.objects(user_id=user_id, status__in=[APPLYING, APPLIED])
            .read_preference(ReadPreference.PRIMARY)
            .order_by("-applied_date")
            .first()
        )

    @classmethod
    def current(cls, user_id):
        """The proposal the Organize sites dialog shows: the user's latest, leaving out proposals a
        revision replaced and revisions that failed, since the proposal they revise is still current."""
        return (
            cls.objects(
                Q(status__ne=REPLACED) & (Q(revises__exists=False) | Q(status__ne=FAILED)), user_id=user_id
            )
            .read_preference(ReadPreference.PRIMARY)
            .order_by("-created_date", "-id")
            .first()
        )

    @classmethod
    def change_decisions(cls, proposal_id, before, after):
        """Save the decisions `after` over `before` on a ready proposal. Returns whether it was ready.

        Each choice is its own field in the update, so two requests that change different choices at
        once both keep theirs.
        """
        before_fields, after_fields = _decision_fields(before), _decision_fields(after)
        update = {
            "$set": {
                "updated_date": datetime.datetime.now(),
                **{
                    name: value
                    for name, value in after_fields.items()
                    if name not in before_fields or before_fields[name] != value
                },
            }
        }
        removed = {name: "" for name in before_fields if name not in after_fields}
        if removed:
            update["$unset"] = removed
        return cls.objects(id=proposal_id, status=READY).update_one(__raw__=update) == 1


def _decision_fields(decisions):
    """{"decisions.<section>.<id>[.<side>]": value} for every choice in `decisions`."""
    fields = {}
    for section, entries in decisions.items():
        for entry_id, value in entries.items():
            if isinstance(value, dict):
                for side, side_value in value.items():
                    fields["decisions.%s.%s.%s" % (section, entry_id, side)] = side_value
            else:
                fields["decisions.%s.%s" % (section, entry_id)] = value
    return fields


class MReorganizeLocks(mongo.Document):
    """The folders a user keeps out of reorganizing, as lists of folder names from the top level.

    A "keep" folder only ever gains copies of sites the user accepts, and a "skip" folder is left
    alone entirely, with every folder inside each (lock_for in apps/reorganize/plan.py).
    """

    user_id = mongo.IntField(required=True, unique=True)
    keep = mongo.ListField(mongo.ListField(mongo.StringField()))
    skip = mongo.ListField(mongo.ListField(mongo.StringField()))
    updated_date = mongo.DateTimeField(default=datetime.datetime.now)

    meta = {
        "collection": "reorganize_locks",
        "allow_inheritance": False,
        "strict": False,
    }

    @classmethod
    def for_user(cls, user_id):
        """The user's locks as apps/reorganize/plan.py takes them."""
        locks = cls.objects(user_id=user_id).read_preference(ReadPreference.PRIMARY).first()
        if locks is None:
            return {"keep": [], "skip": []}
        return {"keep": [list(path) for path in locks.keep], "skip": [list(path) for path in locks.skip]}

    @classmethod
    def save_locks(cls, user_id, keep, skip):
        """Replace the user's locks. Anything that is not a list of folder names is left out."""
        cls.objects(user_id=user_id).update_one(
            set__keep=_folder_paths(keep),
            set__skip=_folder_paths(skip),
            set__updated_date=datetime.datetime.now(),
            upsert=True,
        )


def _folder_paths(paths):
    unique = []
    for path in paths or []:
        if (
            isinstance(path, (list, tuple))
            and path
            and all(isinstance(name, str) for name in path)
            and list(path) not in unique
        ):
            unique.append(list(path))
    return unique
