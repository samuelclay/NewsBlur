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
    DuplicateFeed,
    Feed,
    FeedData,
    MStory,
    merge_feeds,
    merge_feeds_lock,
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
    return "restore-parked-%s-for-%s" % (parked_id, feed_id)


def parked_feed_for(feed_id):
    """The feed an earlier, interrupted run parked for this restore, if any."""
    # The indexed prefix narrows the scan before the suffix picks this restore's row.
    return (
        Feed.objects.filter(
            hash_address_and_link__startswith="restore-parked-",
            hash_address_and_link__endswith="-for-%s" % feed_id,
        )
        .exclude(pk=feed_id)
        .first()
    )


def fold_in_parked_feed(feed_id, parked, log=print):
    """Merge a parked feed into the restored one, keeping the restored id and its parent;
    merge_feeds moves the parked feed's stories across rather than deleting them."""
    survivor = merge_feeds(feed_id, parked.pk, force=True, preserve_branch_from_feed=True)
    if survivor != feed_id or not Feed.objects.filter(pk=feed_id).exists():
        raise CommandError("merge of %s into %s did not keep %s" % (parked.pk, feed_id, feed_id))
    log("merged feed %s into %s" % (parked.pk, feed_id))


def feed_holding_address(fields, feed_id):
    """The feed, other than feed_id, that already holds the restored feed's address: by the
    canonical hash, or by the exact address and link when its stored hash is stale (a save
    with update_fields does not recompute it), the two lookups Feed.save makes on a
    collision."""
    holders = Feed.objects.filter(
        hash_address_and_link=fields["hash_address_and_link"]
    ) | Feed.objects.filter(feed_address=fields.get("feed_address"), feed_link=fields.get("feed_link"))
    return holders.exclude(pk=feed_id).order_by("pk").first()


def stage_restored_feed(feed_object, stale_redirects, collision, log=print):
    """Recreate the feed row, parking the re-added feed that holds its address first, under
    the merge locks of both ids, and fold the parked feed in before letting go of them.

    A merge in flight for the re-added feed (a fetch worker's save colliding with a twin,
    say) holds that feed's lock, has already read it as an ordinary duplicate, and deletes
    its stories on the way out. Parking the row from outside the lock would not change that
    merge's mind, and the fold-in afterwards would find no source and report success with
    the stories gone. Under the locks the collision is looked up again: the merge that held
    the lock until now may have deleted or re-hashed the re-added feed, and whichever row
    holds the address now is the one to park, under its own lock. Returns the parked feed,
    or None when nothing held the address."""
    feed_id = feed_object["pk"]
    while True:
        with merge_feeds_lock(feed_id, collision.pk if collision else None):
            current = feed_holding_address(feed_object["fields"], feed_id)
            if (current.pk if current else None) != (collision.pk if collision else None):
                log(
                    "feed %s no longer holds this address under its lock; %s does"
                    % (collision.pk if collision else "none", current.pk if current else "no feed")
                )
                collision = current
                continue
            # One transaction for the Postgres staging: if recreating the row fails, the
            # re-added feed is not left parked under an invalid hash.
            with transaction.atomic():
                stale_redirects.delete()
                if collision:
                    Feed.objects.filter(pk=collision.pk).update(
                        hash_address_and_link=parking_hash(collision.pk, feed_id)
                    )
                deserialize_and_save(feed_object)
            if collision:
                # The merge touches Mongo and Redis too, so it runs outside the transaction but
                # still under the locks (merge_feeds finds them held and takes nothing new); a
                # rerun finds the parked row and finishes it (see parked_feed_for above).
                fold_in_parked_feed(feed_id, collision, log=log)
            return collision


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
    """Recreate what is missing for the feed in feed_record. Returns a dict of counts."""
    feed_object = json.loads(json.dumps(feed_record["object"]))
    feed_id = feed_object["pk"]
    fields = feed_object["fields"]
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

    if Feed.objects.filter(pk=feed_id).exists():
        log("feed %s already exists, leaving the row alone" % feed_id)
        # An earlier run parked the re-added feed and then failed before or during the
        # merge; finish that first, or its next save would recompute the hash and collide.
        parked = parked_feed_for(feed_id)
        if parked:
            log("feed %s is still parked from an interrupted run, merging it into %s" % (parked.pk, feed_id))
            if not dry_run:
                fold_in_parked_feed(feed_id, parked, log=log)
                counts["collision_merged"] = parked.pk
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
        collision = feed_holding_address(fields, feed_id)
        if collision:
            collision_stories = MStory.objects(story_feed_id=collision.pk).count()
            log(
                "feed %s already holds this address (re-added after the merge, %s stories); its hash is parked so "
                "feed %s can come back, then it is merged into the restored feed and its stories move across"
                % (collision.pk, collision_stories, feed_id)
            )
        log("creating feed %s %s" % (feed_id, fields.get("feed_address")))
        if not dry_run:
            collision = stage_restored_feed(feed_object, stale_redirects, collision, log=log)
            counts["feed_created"] = 1
            if collision:
                counts["collision_merged"] = collision.pk

    for record in feeddata_records:
        if FeedData.objects.filter(feed_id=feed_id).exists():
            break
        log("creating feeddata for feed %s" % feed_id)
        if not dry_run:
            deserialize_and_save(json.loads(json.dumps(record["object"])))
        counts["feeddata_created"] += 1

    for record in subscription_records:
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
