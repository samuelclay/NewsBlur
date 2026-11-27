"""Apply a reviewed reorganization proposal to a user's account, and undo it.

apply_proposal() runs apps/reorganize/plan.py against the stored tree and the user's locks as they
are at that moment, saves the new tree, carries folder settings with apps/reorganize/state.py, and
mutes or unsubscribes the sites the plan names. undo_proposal() puts the tree and those settings
back and unmutes what the apply muted. Sites the apply unsubscribed from stay unsubscribed.

Both hold the user's UserSubscriptionFolders row lock for the whole change. The proposal lives in
MongoDB, outside the Postgres transaction, so the undo snapshot is saved before anything changes
and grows as each step finishes. A proposal whose apply failed partway is left "applying", and
undo_proposal() rolls it back like an applied one.

Each returns {"code": ...}. A refusal changes nothing and returns one of the codes below. Only a
fault raises. A PlanError from plan.py comes before the snapshot is saved, so it leaves everything
as it was.
"""

import datetime

import redis
from django.conf import settings
from django.db import transaction
from django.utils.translation import gettext_lazy

from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.reorganize.models import (
    APPLIED,
    APPLYING,
    FAILED,
    READY,
    UNDONE,
    WORKING,
    MReorganizeLocks,
    MReorganizeProposal,
)
from apps.reorganize.plan import apply_plan, restore_folders
from apps.reorganize.state import carry_folder_state, revert_folder_state
from apps.rss_feeds.models import DuplicateFeed, Feed
from utils import json_functions as json

UNDO_DAYS = 30

# The backup email's reason, the one move_feeds_by_folder_to_folder in apps/reader/views.py gives.
BACKUP_REASON = gettext_lazy(
    "You have moved a number of feeds at once, so here's a backup of all of your subscriptions just in case."
)

# Outcomes. Every code but APPLIED_CODE and UNDONE_CODE is a refusal.
APPLIED_CODE = "applied"
UNDONE_CODE = "undone"
NOT_FOUND = "not_found"  # the proposal belongs to another user
ARCHIVE_REQUIRED = "archive_required"  # applying needs Premium Archive or Premium Pro
NOT_READY = "not_ready"  # the proposal is still being made, or could not be made
ALREADY_APPLIED = "already_applied"  # the proposal was applied before, and maybe undone since
NOT_APPLIED = "not_applied"  # there is nothing to undo
EXPIRED = "expired"  # the apply started more than UNDO_DAYS ago
SUPERSEDED = "superseded"  # a later proposal has been applied since


def apply_proposal(user, proposal_doc):
    """Apply `proposal_doc` with its stored decisions. Returns {"code", "result", "folders"}."""
    refusal = _apply_refusal(user, proposal_doc)
    if refusal:
        return {"code": refusal}

    with transaction.atomic():
        user_folders = UserSubscriptionFolders.objects.select_for_update().get(user=user)
        stored_before = user_folders.folders
        folders_before = json.decode(stored_before) or []
        plan = apply_plan(
            folders_before,
            proposal_doc.proposal,
            proposal_doc.decisions,
            MReorganizeLocks.for_user(user.pk),
        )
        if not _start_apply(proposal_doc, stored_before):
            return {"code": ALREADY_APPLIED}

        # The web's bulk moves and deletes in apps/reader/views.py send the same backup first.
        user.profile.send_opml_export_email(reason=BACKUP_REASON)

        user_folders.folders = json.encode(plan.folders)
        user_folders.save(update_fields=["folders"])
        carried = carry_folder_state(user, plan.path_changes, folders_before, plan.folders)
        _record_undo(proposal_doc, carried=carried)
        muted_feed_ids = _mute(user, plan.mute_feed_ids)
        _record_undo(proposal_doc, muted_feed_ids=muted_feed_ids)
        unsubscribed_feed_ids = _unsubscribe(user, plan.unsubscribe_feed_ids)
        _reload_feeds_on_commit(user)

    result = {
        "moved": len(plan.moved),
        "copied": len(plan.copied),
        "folders_created": len(plan.created),
        "folders_changed": len(plan.path_changes),
        "folders_merged": len(plan.merged),
        "folders_removed": len(plan.removed),
        "muted": len(muted_feed_ids),
        "unsubscribed": len(unsubscribed_feed_ids),
        "skipped": plan.skipped,
    }
    _finish(proposal_doc, [APPLYING], set__status=APPLIED, set__result=result)
    return {"code": APPLIED_CODE, "result": result, "folders": plan.folders}


def undo_proposal(user, proposal_doc):
    """Put back the tree and folder settings `proposal_doc` changed. Returns {"code", "folders"}."""
    refusal = undo_refusal(user, proposal_doc)
    if refusal:
        return {"code": refusal}

    with transaction.atomic():
        user_folders = UserSubscriptionFolders.objects.select_for_update().get(user=user)
        # Checked again under the lock, which an apply of a later proposal also holds.
        proposal_doc.reload()
        refusal = undo_refusal(user, proposal_doc)
        if refusal:
            return {"code": refusal}

        subscribed_feed_ids = UserSubscription.objects.filter(user=user).values_list("feed_id", flat=True)
        folders = restore_folders(
            json.decode(proposal_doc.undo["folders"]) or [],
            json.decode(user_folders.folders) or [],
            subscribed_feed_ids,
        )
        user_folders.folders = json.encode(folders)
        user_folders.save(update_fields=["folders"])
        revert_folder_state(user, proposal_doc.undo.get("carried"))
        _unmute(user, proposal_doc.undo.get("muted_feed_ids", []))
        _reload_feeds_on_commit(user)

    _finish(proposal_doc, [APPLYING, APPLIED], set__status=UNDONE, set__undone_date=datetime.datetime.now())
    return {"code": UNDONE_CODE, "folders": folders}


def _apply_refusal(user, proposal_doc):
    if proposal_doc.user_id != user.pk:
        return NOT_FOUND
    if not (user.profile.is_archive or user.profile.is_pro):
        return ARCHIVE_REQUIRED
    if proposal_doc.status in (WORKING, FAILED):
        return NOT_READY
    if proposal_doc.status != READY:
        return ALREADY_APPLIED
    return None


def undo_refusal(user, proposal_doc):
    """Why `proposal_doc` cannot be undone now, or None if it can."""
    if proposal_doc.user_id != user.pk:
        return NOT_FOUND
    if proposal_doc.status not in (APPLYING, APPLIED):
        return NOT_APPLIED
    if proposal_doc.applied_date < datetime.datetime.now() - datetime.timedelta(days=UNDO_DAYS):
        return EXPIRED
    last_applied = MReorganizeProposal.last_applied(user.pk)
    if last_applied is None or last_applied.id != proposal_doc.id:
        return SUPERSEDED
    return None


def _start_apply(proposal_doc, stored_folders):
    """Claim a ready proposal for this apply and save its undo snapshot. False if another took it."""
    now = datetime.datetime.now()
    claimed = MReorganizeProposal.objects(id=proposal_doc.id, status=READY).update_one(
        set__status=APPLYING,
        set__applied_date=now,
        set__updated_date=now,
        set__undo={"folders": stored_folders, "carried": [], "muted_feed_ids": []},
    )
    return claimed == 1


def _record_undo(proposal_doc, **fields):
    MReorganizeProposal.objects(id=proposal_doc.id).update_one(
        **{"set__undo__%s" % name: value for name, value in fields.items()}
    )


def _finish(proposal_doc, from_statuses, **updates):
    """Move the proposal on from `from_statuses`, unless a concurrent apply or undo already has."""
    MReorganizeProposal.objects(id=proposal_doc.id, status__in=from_statuses).update_one(
        set__updated_date=datetime.datetime.now(), **updates
    )
    proposal_doc.reload()


def _mute(user, feed_ids):
    """Mute every active subscription among `feed_ids`, as set_feed_mute in apps/reader/views.py
    mutes a site with no end date, and return the feed ids muted."""
    muted = []
    for subscription in UserSubscription.objects.filter(user=user, feed_id__in=feed_ids, active=True):
        subscription.active = False
        subscription.mute_expires_at = None
        subscription.save(update_fields=["active", "mute_expires_at"])
        muted.append(subscription.feed_id)
    return muted


def _unmute(user, feed_ids):
    """Unmute the subscriptions among `feed_ids` that are still muted, as set_feed_mute in
    apps/reader/views.py does."""
    for subscription in UserSubscription.objects.filter(user=user, feed_id__in=list(feed_ids), active=False):
        subscription.active = True
        subscription.mute_expires_at = None
        subscription.save(update_fields=["active", "mute_expires_at"])
        feed = subscription.feed
        if feed.active_subscribers <= 0:
            transaction.on_commit(feed.count_subscribers)


def _unsubscribe(user, feed_ids):
    """Delete the subscription behind each of `feed_ids`, which the new tree no longer lists, and
    return the feed ids of the subscriptions deleted.

    Each is found as UserSubscriptionFolders.delete_feed in apps/reader/models.py finds it: by the
    feed id, or else through the feed a merged duplicate's id now points to. Subscriber counts are
    recounted once the change commits, as delete_feed in apps/reader/views.py recounts them.
    """
    unsubscribed = []
    for feed_id in feed_ids:
        subscription = UserSubscription.objects.filter(user=user, feed_id=feed_id).first()
        if subscription is None:
            duplicate = DuplicateFeed.objects.filter(duplicate_feed_id=str(feed_id)).first()
            if duplicate is not None:
                subscription = UserSubscription.objects.filter(user=user, feed_id=duplicate.feed_id).first()
        if subscription is None:
            continue
        subscription.delete()
        unsubscribed.append(subscription.feed_id)
        transaction.on_commit(lambda feed_id=subscription.feed_id: _recount_subscribers(feed_id))
    return unsubscribed


def _recount_subscribers(feed_id):
    feed = Feed.objects.filter(pk=feed_id).first()
    if feed is not None:
        feed.count_subscribers()


def _reload_feeds_on_commit(user):
    """Tell the user's other open clients to reload their feeds, as the web's folder actions do."""
    transaction.on_commit(
        lambda: redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL).publish(user.username, "reload:feeds")
    )
