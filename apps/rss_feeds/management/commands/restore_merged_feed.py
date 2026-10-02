"""
restore_merged_feed: undo a merge_feeds that went wrong, from the task logs alone.

merge_feeds (apps/rss_feeds/models.py) logs a MERGE_FEEDS_INVENTORY JSON line for every
feed row, FeedData row, and subscription it is about to touch, with the folder each reader
kept the feed in. This command reads those lines back and recreates whatever is missing
for one feed id: the Feed row with its original id, its FeedData, each subscription that
no longer exists (readers who left in the meantime are skipped), and the feed's entry in
each reader's folder tree (the logged folder when it still exists, otherwise the root).
Nothing that still exists is overwritten.

    docker exec -t newsblur_web python manage.py restore_merged_feed --log /tmp/task.log --feed-id 7284245 --dry-run
    docker exec -t newsblur_web python manage.py restore_merged_feed --log /tmp/task.log --feed-id 7284245

Gather the log with, for example:
    docker logs task-celery --since 48h 2>&1 | grep MERGE_FEEDS_INVENTORY > /tmp/task.log

If a reader re-added the same address after the bad merge, the new feed row holds the
address hash the restored row needs; that row is folded into the restored feed with
merge_feeds afterwards, which moves its subscriptions and folder entries over.
apps/rss_feeds/management/commands/restore_merged_feed.py
"""

import json

from django.contrib.auth.models import User
from django.core import serializers
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.rss_feeds.models import (
    MERGE_FEEDS_INVENTORY_PREFIX,
    RESTORE_PARKED_HASH_PREFIX,
    DuplicateFeed,
    Feed,
    FeedData,
    MMergeFeedsPrivateInventory,
    MStory,
    merge_feeds,
    merge_feeds_lock,
    renew_merge_feeds_locks,
)
from utils import json_functions
from utils import log as logging


def parse_inventory(lines):
    """Every MERGE_FEEDS_INVENTORY record in the lines, in order, ignoring anything else."""
    records = []
    marker = MERGE_FEEDS_INVENTORY_PREFIX + " "
    for line in lines:
        if marker not in line:
            continue
        payload = line.split(marker, 1)[1].strip()
        try:
            records.append(json.loads(payload))
        except ValueError:
            continue
    return records


def inventory_snapshots(records, feed_id):
    """The logged_at of every inventory that recorded feed_id, oldest first."""
    return sorted(
        {r["merge"]["logged_at"] for r in records if r.get("type") == "feed" and r["object"]["pk"] == feed_id}
    )


def inventory_is_complete(records, feed_record):
    """True when the inventory that logged feed_record has its summary and as many
    subscription records for this feed as the summary counted."""
    merge = feed_record["merge"]
    feed_id = feed_record["object"]["pk"]
    summaries = [r for r in records if r.get("type") == "summary" and r.get("merge") == merge]
    if not summaries:
        return False
    expected = summaries[0].get("%s_subscriptions" % feed_record["role"])
    logged = sum(
        1
        for r in records
        if r.get("type") == "subscription"
        and r.get("merge") == merge
        and r["object"]["fields"]["feed"] == feed_id
    )
    return expected is not None and logged == expected


def inventory_for_feed(records, feed_id, snapshot=None):
    """The feed, feeddata, and subscription records for feed_id from one inventory.

    The oldest inventory is used unless `snapshot` names a logged_at: a merge that failed
    partway and was retried logs a second inventory holding only the readers it had not
    moved yet, so the first one is the complete picture. Returns
    (feed_record, feeddata_records, subscription_records)."""
    feed_records = [r for r in records if r.get("type") == "feed" and r["object"]["pk"] == feed_id]
    if snapshot:
        feed_records = [r for r in feed_records if r["merge"]["logged_at"].startswith(snapshot)]
    else:
        # The feed may appear in several merges over time (it survived one, then was merged
        # into another feed later); the most recent merge is the one being undone, and its
        # retries share the same feed pair.
        # Inventories logged by a recovery merge (folding a parked feed into the feed being
        # restored) describe the restore in progress, not the merge being undone.
        feed_records = [r for r in feed_records if not r["merge"].get("recovery")]
        latest = max(feed_records, key=lambda r: r["merge"]["logged_at"], default=None)
        if latest:
            pair = (latest["merge"]["original_feed_id"], latest["merge"]["duplicate_feed_id"])
            feed_records = [
                r
                for r in feed_records
                if (r["merge"]["original_feed_id"], r["merge"]["duplicate_feed_id"]) == pair
            ]
        # A worker that died while logging leaves an inventory without its summary, or with
        # fewer subscription records than the summary counts; only complete ones qualify.
        feed_records = [r for r in feed_records if inventory_is_complete(records, r)]
    if not feed_records:
        return None, [], []
    feed_record = sorted(feed_records, key=lambda r: r["merge"]["logged_at"])[0]
    merge = feed_record["merge"]

    def same_merge(record):
        return record.get("merge") == merge

    feeddata_records = [
        r
        for r in records
        if r.get("type") == "feeddata" and same_merge(r) and r["object"]["fields"]["feed"] == feed_id
    ]
    subscription_records = [
        r
        for r in records
        if r.get("type") == "subscription" and same_merge(r) and r["object"]["fields"]["feed"] == feed_id
    ]
    return feed_record, feeddata_records, subscription_records


def folder_at_path(folders, path):
    """The children list of the folder at `path` (names from the top, matched
    case-insensitively level by level), the root list for [], or None when the reader no
    longer has that exact folder. Same-named folders under different parents stay apart."""
    if not path:
        return folders
    wanted, rest = path[0], path[1:]
    for item in folders:
        if isinstance(item, dict):
            for name, children in item.items():
                if name.lower() == wanted.lower():
                    return folder_at_path(children, rest)
    return None


def add_feed_at_path(folders, path, feed_id, log=print, user_id=None):
    """Put feed_id into the folder at `path`, or into the root when that folder is gone."""
    target = folder_at_path(folders, path)
    if target is None:
        log(
            "user %s no longer has folder %s, adding feed %s to the root" % (user_id, "/".join(path), feed_id)
        )
        target = folders
    if feed_id not in [item for item in target if isinstance(item, int)]:
        target.append(feed_id)
    return folders


def parking_hash(parked_id, feed_id):
    """The placeholder hash a re-added feed carries while feed_id is being restored. It names
    the target, so a later restore for another feed at the same address (different link)
    never picks up this row."""
    return "%s%s-for-%s" % (RESTORE_PARKED_HASH_PREFIX, parked_id, feed_id)


def parked_feeds_for(feed_id):
    """The feeds an earlier, interrupted run parked for this restore, oldest first."""
    # The indexed prefix narrows the scan before the suffix picks this restore's rows.
    return list(
        Feed.objects.filter(
            hash_address_and_link__startswith=RESTORE_PARKED_HASH_PREFIX,
            hash_address_and_link__endswith="-for-%s" % feed_id,
        )
        .exclude(pk=feed_id)
        .order_by("pk")
    )


def parked_feed_for(feed_id):
    """The first feed an earlier, interrupted run parked for this restore, if any."""
    parked = parked_feeds_for(feed_id)
    return parked[0] if parked else None


def fold_in_parked_feed(feed_id, parked, log=print):
    """Merge a parked feed into the restored one, keeping the restored id and its parent;
    merge_feeds moves the parked feed's stories across rather than deleting them."""
    survivor = merge_feeds(feed_id, parked.pk, force=True, preserve_branch_from_feed=True)
    if survivor != feed_id or not Feed.objects.filter(pk=feed_id).exists():
        raise CommandError("merge of %s into %s did not keep %s" % (parked.pk, feed_id, feed_id))
    log("merged feed %s into %s" % (parked.pk, feed_id))


def feeds_holding_address(fields, feed_id):
    """Every feed, other than feed_id, that already holds the restored feed's address: the
    holder of the canonical hash first, then feeds carrying the exact address and link under
    a stale hash. All of them are parked and folded in; a stale twin left behind would
    collide with the restored feed on its own next full save and could merge it away."""
    return Feed.feeds_holding_address(
        fields.get("feed_address"), fields.get("feed_link"), exclude_ids=[feed_id]
    )


def keep_parent_away_from_the_collision(fields, collision, log=print):
    """A restored branch must not be folded together with its own parent. The recorded parent
    can resolve, through DuplicateFeed, to the very feed that holds the restored address,
    and merge_feeds clears a survivor's parent when that parent is the feed being merged
    away, which would leave a private URL public in discovery. When that feed has a parent
    of its own the restored feed is re-parented to it; otherwise the restore refuses, before
    anything is written."""
    if not collision or fields.get("branch_from_feed") != collision.pk:
        return
    if collision.branch_from_feed_id:
        log(
            "feed %s holds this address and is also the restored feed's parent; re-parenting the restored "
            "feed to %s so folding %s in cannot leave it public"
            % (collision.pk, collision.branch_from_feed_id, collision.pk)
        )
        fields["branch_from_feed"] = collision.branch_from_feed_id
        return
    raise CommandError(
        "feed %s holds the restored feed's address and is also its parent; merging it into the restored "
        "feed would clear the parent and make a private branch public. Remove or re-address feed %s "
        "first, or restore by hand" % (collision.pk, collision.pk)
    )


def stage_restored_feed(feed_object, stale_redirects, collisions, log=print):
    """Recreate the feed row, parking every re-added feed that holds its address first, and
    fold the parked feeds in. Runs under the merge locks of the restored id and of all of
    them, which restore_feed_from_inventory holds from here until the feed's subscriptions
    are back and it has been recounted. Returns the feeds parked and folded in.

    A merge in flight for a re-added feed (a fetch worker's save colliding with a twin,
    say) holds that feed's lock, has already read it as an ordinary duplicate, and deletes
    its stories on the way out. Parking the row from outside the lock would not change that
    merge's mind, and the fold-in afterwards would find no source and report success with
    the stories gone."""
    feed_id = feed_object["pk"]
    for collision in collisions:
        keep_parent_away_from_the_collision(feed_object["fields"], collision, log=log)
    # One transaction for the Postgres staging: if recreating the row fails, the re-added
    # feeds are not left parked under placeholder hashes.
    with transaction.atomic():
        stale_redirects.delete()
        for collision in collisions:
            parked_fields = {"hash_address_and_link": parking_hash(collision.pk, feed_id)}
            if feed_object["fields"].get("branch_from_feed"):
                # A copy re-added at a private branch's address carries the same token.
                # Marked as a branch of the same parent, the merge's log lines and the
                # recovery's inventory name it by id, like the restored feed itself.
                parked_fields["branch_from_feed_id"] = feed_object["fields"]["branch_from_feed"]
            Feed.objects.filter(pk=collision.pk).update(**parked_fields)
        deserialize_and_save(feed_object)
    for collision in collisions:
        # The merge touches Mongo and Redis too, so it runs outside the transaction but
        # still under the locks (merge_feeds finds them held and takes nothing new); a
        # rerun finds the parked rows and finishes them (see parked_feeds_for above).
        fold_in_parked_feed(feed_id, collision, log=log)
    return collisions


def tree_holds_feed(folders, feed_id):
    for item in folders:
        if isinstance(item, int) and item == feed_id:
            return True
        if isinstance(item, dict):
            for children in item.values():
                if tree_holds_feed(children, feed_id):
                    return True
    return False


def deserialize_and_save(serialized_object):
    deserialized = list(serializers.deserialize("json", json.dumps([serialized_object])))[0]
    deserialized.save()
    return deserialized.object


def restore_feed_from_inventory(
    feed_record,
    feeddata_records,
    subscription_records,
    dry_run=False,
    log=print,
):
    """Recreate what is missing for the feed in feed_record. Returns a dict of counts.

    Everything that writes runs under the merge locks of the restored id and of every feed
    parked for it, from recreating the row through restoring its subscriptions and folders
    to the recount: a fetch let in between the row and its subscriptions would recount the
    feed's Archive readers as none and trim the recovered stories to the short retention,
    which no rerun could bring back since the inventory holds no story content. A fetch
    that arrives meanwhile waits briefly and comes back a few minutes later."""
    feed_object = json.loads(json.dumps(feed_record["object"]))
    feed_id = feed_object["pk"]
    fields = feed_object["fields"]
    if feed_record.get("private"):
        # The log carries placeholders for a private branch's address and link; the real
        # values were kept in the database when the inventory was logged.
        kept = MMergeFeedsPrivateInventory.lookup(feed_id, feed_record["merge"]["logged_at"])
        if kept is None:
            raise CommandError(
                "feed %s is a private branch and its address is not on file for the inventory logged at %s; "
                "pass it by hand with a fixed-up log" % (feed_id, feed_record["merge"]["logged_at"])
            )
        fields["feed_address"] = kept.feed_address
        fields["feed_link"] = kept.feed_link
    display_address = (
        "private feed %s address" % feed_id if feed_record.get("private") else fields.get("feed_address")
    )
    counts = {
        "feed_created": 0,
        "feeddata_created": 0,
        "subscriptions_created": 0,
        "subscriptions_existing": 0,
        "subscriptions_skipped_missing_user": 0,
        "folders_added": 0,
        "folders_existing": 0,
        "collision_merged": None,
    }

    row_missing = not Feed.objects.filter(pk=feed_id).exists()
    stale_redirects = DuplicateFeed.objects.none()
    collisions = []
    if not row_missing:
        log("feed %s already exists, leaving the row alone" % feed_id)
    else:
        # Similar-feed links are a many-to-many to other feeds that may be gone.
        fields.pop("similar_feeds", None)
        # A branch stays a branch: a null parent is what makes a feed public in discovery,
        # and a branch can be a reader's private token URL. When the recorded parent was
        # itself merged away, DuplicateFeed says which feed took its place.
        parent_id = fields.get("branch_from_feed")
        if parent_id and not Feed.objects.filter(pk=parent_id).exists():
            redirect = DuplicateFeed.objects.filter(duplicate_feed_id=parent_id).first()
            if redirect is None:
                raise CommandError(
                    "feed %s was a branch of feed %s, which no longer exists and was not merged anywhere; "
                    "restore the parent first so the branch does not become public" % (feed_id, parent_id)
                )
            log(
                "branch parent %s was merged into %s, restoring feed %s under it"
                % (parent_id, redirect.feed_id, feed_id)
            )
            fields["branch_from_feed"] = redirect.feed_id
        # The merge that lost this feed left a redirect from its id to the survivor; a
        # saved story or an import would follow it straight back out.
        # This id's redirects, plus the row that carries this feed's exact address and link
        # (after a chain A into B into C, merge_feeds rewrote A's row to point at B's id but
        # kept A's address). A feed sharing only the address with a different link keeps its row.
        stale_redirects = DuplicateFeed.objects.filter(
            duplicate_feed_id=feed_id
        ) | DuplicateFeed.objects.filter(
            duplicate_address=fields["feed_address"], duplicate_link=fields["feed_link"]
        )
        if stale_redirects.exists():
            log("removing %s stale duplicate-feed redirects for feed %s" % (stale_redirects.count(), feed_id))
        # merge_feeds deleted the feed's stories, so the row must fetch afresh: cached
        # validators would let an unchanged publisher answer 304 and leave it empty.
        fields["etag"] = None
        fields["last_modified"] = None
        fields["fetched_once"] = False
        # The logged hash can be stale (a save with update_fields=["feed_link"] does not
        # recompute it); the canonical hash is what a later save would collide on.
        fields["hash_address_and_link"] = Feed.generate_hash_address_and_link(
            fields.get("feed_address"), fields.get("feed_link")
        )
        collisions = feeds_holding_address(fields, feed_id)
        for collision in collisions:
            collision_stories = MStory.objects(story_feed_id=collision.pk).count()
            log(
                "feed %s already holds this address (re-added after the merge, %s stories); its hash is parked so "
                "feed %s can come back, then it is merged into the restored feed and its stories move across"
                % (collision.pk, collision_stories, feed_id)
            )
            keep_parent_away_from_the_collision(fields, collision, log=log)
        log("creating feed %s %s" % (feed_id, display_address))

    if dry_run:
        return restore_the_rest(
            feed_id, feeddata_records, subscription_records, counts, dry_run=True, log=log
        )

    lock_ids = {feed_id} | {feed.pk for feed in collisions} | {feed.pk for feed in parked_feeds_for(feed_id)}
    while True:
        with merge_feeds_lock(*lock_ids):
            if row_missing:
                if Feed.objects.filter(pk=feed_id).exists():
                    # Another restore of the same feed got here first; only what it has not
                    # done yet is done below.
                    log(
                        "feed %s was recreated by another restore while this one waited; leaving the row alone"
                        % feed_id
                    )
                    row_missing = False
                else:
                    # The address holders are looked up again under the locks: a merge that
                    # held one of their locks until now may have deleted or re-hashed a
                    # re-added feed, and whichever rows hold the address now are the ones to
                    # park, under their own locks.
                    current = feeds_holding_address(fields, feed_id)
                    if {feed.pk for feed in current} != {feed.pk for feed in collisions}:
                        log(
                            "the feeds holding this address changed under the lock: %s now, %s before"
                            % (
                                [feed.pk for feed in current] or "none",
                                [feed.pk for feed in collisions] or "none",
                            )
                        )
                        collisions = current
                        lock_ids = (
                            {feed_id}
                            | {feed.pk for feed in collisions}
                            | {feed.pk for feed in parked_feeds_for(feed_id)}
                        )
                        continue
                    parked = stage_restored_feed(feed_object, stale_redirects, collisions, log=log)
                    counts["feed_created"] = 1
                    if parked:
                        counts["collision_merged"] = parked[0].pk
                        counts["collisions_merged"] = [feed.pk for feed in parked]
            return restore_the_rest(
                feed_id, feeddata_records, subscription_records, counts, dry_run=False, log=log
            )


def restore_the_rest(feed_id, feeddata_records, subscription_records, counts, dry_run=False, log=print):
    """Past the row: parked feeds an interrupted run left, the feed data, every subscription
    with its folder entry, then the recount, the Redis rebuild, the reindex and the fetch.
    Under the restore's locks when writing (a rerun that found the row in place holds them
    too), renewing their leases per record for a popular feed."""
    # An earlier run parked a feed for this restore and stopped before merging it, or the
    # parked feed followed a redirect away from the restored address meanwhile and the
    # address lookup no longer sees it; its marker still names this feed.
    for parked in parked_feeds_for(feed_id):
        log("feed %s is still parked from an interrupted run, merging it into %s" % (parked.pk, feed_id))
        if not dry_run:
            fold_in_parked_feed(feed_id, parked, log=log)
            counts["collision_merged"] = parked.pk
            counts.setdefault("collisions_merged", []).append(parked.pk)

    for record in feeddata_records:
        if FeedData.objects.filter(feed_id=feed_id).exists():
            break
        log("creating feeddata for feed %s" % feed_id)
        if not dry_run:
            deserialize_and_save(json.loads(json.dumps(record["object"])))
        counts["feeddata_created"] += 1

    for record in subscription_records:
        renew_merge_feeds_locks()
        subscription_object = json.loads(json.dumps(record["object"]))
        user_id = subscription_object["fields"]["user"]
        if not User.objects.filter(pk=user_id).exists():
            counts["subscriptions_skipped_missing_user"] += 1
            continue
        if UserSubscription.objects.filter(user_id=user_id, feed_id=feed_id).exists():
            counts["subscriptions_existing"] += 1
        else:
            if UserSubscription.objects.filter(pk=subscription_object["pk"]).exists():
                # The old row id belongs to another subscription now; take a fresh id.
                subscription_object["pk"] = None
            # Counts in the log predate whatever the feed collected since (a re-added feed's
            # stories, for one); the next unread count recomputes them.
            subscription_object["fields"]["needs_unread_recalc"] = True
            log("creating subscription for user %s" % user_id)
            if not dry_run:
                deserialize_and_save(subscription_object)
            counts["subscriptions_created"] += 1

        placements = record.get("folders") or [[]]
        folder_row = UserSubscriptionFolders.objects.filter(user_id=user_id).first()
        tree = json_functions.decode(folder_row.folders) if folder_row and folder_row.folders else []
        if tree_holds_feed(tree, feed_id):
            counts["folders_existing"] += 1
            continue
        for path in placements:
            log("adding feed %s to user %s folder %s" % (feed_id, user_id, "/".join(path) or "root"))
            tree = add_feed_at_path(tree, path, feed_id, log=log, user_id=user_id)
        counts["folders_added"] += 1
        if not dry_run:
            if folder_row is None:
                folder_row = UserSubscriptionFolders(user_id=user_id)
            folder_row.folders = json_functions.encode(tree)
            folder_row.save()

    # Always, not only when the row was created here: a restore interrupted after creating
    # the feed is rerun, and the recount and fetch schedule must still happen.
    if not dry_run:
        renew_merge_feeds_locks()
        feed = Feed.get_by_id(feed_id)
        feed.count_subscribers()
        # Stories moved in from a re-added feed were added to Redis under the restored feed's
        # unread cutoff as of before its subscribers were recounted; an Archive reader among
        # them widens that cutoff. Rebuilt on every run, so a restore interrupted after the
        # parked row went (when the rerun no longer sees a collision) still gets it.
        feed.sync_redis()
        # A story move that stopped after its Mongo write but before indexing leaves search
        # and discovery entries missing for a document a rerun no longer touches, so the
        # restored feed is reindexed wholesale according to its own indexing flags.
        if feed.search_indexed:
            feed.index_stories_for_search(force=True)
        if feed.discover_indexed:
            feed.index_stories_for_discover(force=True)
        feed.schedule_feed_fetch_immediately()
        logging.info(
            " ---> restore_merged_feed: feed %s back with %s subscribers" % (feed_id, feed.num_subscribers)
        )
    return counts


class Command(BaseCommand):
    help = "Recreate a feed, its subscriptions, and its folder entries from MERGE_FEEDS_INVENTORY log lines."

    def add_arguments(self, parser):
        parser.add_argument(
            "--log", dest="log", required=True, help="File holding MERGE_FEEDS_INVENTORY lines"
        )
        parser.add_argument(
            "--feed-id", dest="feed_id", type=int, required=True, help="Feed id to bring back"
        )
        parser.add_argument("--dry-run", dest="dry_run", action="store_true", help="Report without writing")
        parser.add_argument(
            "--snapshot",
            dest="snapshot",
            default=None,
            help="logged_at (or a prefix) of the inventory to restore from; default is the oldest for the feed",
        )

    def handle(self, *args, **options):
        with open(options["log"]) as handle:
            records = parse_inventory(handle)
        snapshots = inventory_snapshots(records, options["feed_id"])
        feed_record, feeddata_records, subscription_records = inventory_for_feed(
            records, options["feed_id"], snapshot=options["snapshot"]
        )
        if not feed_record:
            raise CommandError(
                "No MERGE_FEEDS_INVENTORY record for feed %s in %s (snapshots on file: %s)"
                % (options["feed_id"], options["log"], ", ".join(snapshots) or "none")
            )
        if len(snapshots) > 1:
            self.stdout.write(
                "%s inventories on file for feed %s (%s); using %s, pass --snapshot to pick another"
                % (
                    len(snapshots),
                    options["feed_id"],
                    ", ".join(snapshots),
                    feed_record["merge"]["logged_at"],
                )
            )
        self.stdout.write(
            "Inventory from merge of %(duplicate_feed_id)s into %(original_feed_id)s at %(logged_at)s"
            % feed_record["merge"]
        )
        counts = restore_feed_from_inventory(
            feed_record,
            feeddata_records,
            subscription_records,
            dry_run=options["dry_run"],
            log=lambda message: self.stdout.write(("DRY RUN: " if options["dry_run"] else "") + message),
        )
        for key, value in counts.items():
            self.stdout.write("%s: %s" % (key, value))
