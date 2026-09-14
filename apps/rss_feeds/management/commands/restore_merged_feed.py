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

from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.rss_feeds.models import (
    MERGE_FEEDS_INVENTORY_PREFIX,
    Feed,
    FeedData,
    merge_feeds,
)
from utils import json_functions
from utils import log as logging
from utils.feed_functions import add_object_to_folder


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


def inventory_for_feed(records, feed_id):
    """The feed, feeddata, and subscription records for feed_id from the latest merge that
    logged it. Returns (feed_record, feeddata_records, subscription_records)."""
    feed_records = [r for r in records if r.get("type") == "feed" and r["object"]["pk"] == feed_id]
    if not feed_records:
        return None, [], []
    feed_record = feed_records[-1]
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


def folder_name_in_tree(folders, wanted):
    """The folder name as spelled in this tree for a logged name, matched case-insensitively,
    or None when the reader no longer has that folder."""
    for item in folders:
        if isinstance(item, dict):
            for name, children in item.items():
                if name.lower() == wanted.lower():
                    return name
                found = folder_name_in_tree(children, wanted)
                if found:
                    return found
    return None


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
    feed_record, feeddata_records, subscription_records, dry_run=False, log=print
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
    else:
        # Similar-feed links are a many-to-many to other feeds that may be gone; the branch
        # parent may be gone too (it usually was the deleted duplicate).
        fields.pop("similar_feeds", None)
        parent_id = fields.get("branch_from_feed")
        if parent_id and not Feed.objects.filter(pk=parent_id).exists():
            log("branch parent %s no longer exists, restoring feed %s with no parent" % (parent_id, feed_id))
            fields["branch_from_feed"] = None
        collision = (
            Feed.objects.filter(hash_address_and_link=fields["hash_address_and_link"])
            .exclude(pk=feed_id)
            .first()
        )
        if collision:
            log(
                "feed %s already holds this address (re-added after the merge); its hash is parked so feed %s can "
                "come back, then it is merged into the restored feed" % (collision.pk, feed_id)
            )
        log("creating feed %s %s" % (feed_id, fields.get("feed_address")))
        if not dry_run:
            if collision:
                Feed.objects.filter(pk=collision.pk).update(
                    hash_address_and_link="restore-parked-%s" % collision.pk
                )
            deserialize_and_save(feed_object)
            counts["feed_created"] = 1
            if collision:
                survivor = merge_feeds(feed_id, collision.pk)
                counts["collision_merged"] = collision.pk
                log("merged feed %s into %s, survivor %s" % (collision.pk, feed_id, survivor))

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
            log("creating subscription for user %s" % user_id)
            if not dry_run:
                deserialize_and_save(subscription_object)
            counts["subscriptions_created"] += 1

        placements = record.get("folders") or [""]
        folder_row = UserSubscriptionFolders.objects.filter(user_id=user_id).first()
        tree = json_functions.decode(folder_row.folders) if folder_row and folder_row.folders else []
        if tree_holds_feed(tree, feed_id):
            counts["folders_existing"] += 1
            continue
        for wanted in placements:
            target = folder_name_in_tree(tree, wanted) if wanted else None
            target = target or ""
            log(
                "adding feed %s to user %s folder %s" % (feed_id, user_id, repr(target) if target else "root")
            )
            tree = add_object_to_folder(feed_id, target, tree)
        counts["folders_added"] += 1
        if not dry_run:
            if folder_row is None:
                folder_row = UserSubscriptionFolders(user_id=user_id)
            folder_row.folders = json_functions.encode(tree)
            folder_row.save()

    if not dry_run and counts["feed_created"]:
        feed = Feed.get_by_id(feed_id)
        feed.count_subscribers()
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

    def handle(self, *args, **options):
        with open(options["log"]) as handle:
            records = parse_inventory(handle)
        feed_record, feeddata_records, subscription_records = inventory_for_feed(records, options["feed_id"])
        if not feed_record:
            raise CommandError(
                "No MERGE_FEEDS_INVENTORY record for feed %s in %s" % (options["feed_id"], options["log"])
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
