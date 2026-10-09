"""Reader tasks: periodic maintenance for homepage freshening and analytics cleanup."""

import datetime
import time

import redis
from django.conf import settings
from django.contrib.auth.models import User

from apps.reader.models import UserSubscription
from apps.social.models import MSocialSubscription
from newsblur_web.celeryapp import app
from utils import log as logging


@app.task(name="maintain-feed-subscriptions")
def MaintainFeedSubscriptions(user_id, changed, feed_ids):
    # apps/reader/tasks.py keeps search, Redis, and subscriber maintenance outside the batch HTTP request.
    from apps.rss_feeds.models import Feed
    from apps.search.models import MUserSearch
    from apps.social.models import MActivity
    from apps.statistics.rtrending_subscriptions import RTrendingSubscription

    user = User.objects.filter(pk=user_id).first()
    if user is None:
        return
    feeds = Feed.objects.in_bulk(feed_id for feed_id, _ in changed)
    for feed_id, created in changed:
        feed = feeds.get(feed_id)
        if feed is None:
            continue
        if created:
            MActivity.new_feed_subscription(user_id=user_id, feed_id=feed.pk, feed_title=feed.title)
            RTrendingSubscription.add_subscription(feed_id=feed.pk)
        feed.setup_feed_for_premium_subscribers(
            allow_skip_resync=user.profile.is_archive and feed.active_premium_subscribers != 0
        )
        if feed.archive_count:
            feed.schedule_fetch_archive_feed()
    MUserSearch.schedule_index_feeds_for_search(feed_ids, user_id)
    redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL).publish(user.username, "reload:feeds")


@app.task(name="freshen-homepage")
def FreshenHomepage():
    day_ago = datetime.datetime.utcnow() - datetime.timedelta(days=1)
    user = User.objects.get(username=settings.HOMEPAGE_USERNAME)
    user.profile.last_seen_on = datetime.datetime.utcnow()
    user.profile.save()

    usersubs = UserSubscription.objects.filter(user=user)
    logging.debug(" ---> %s has %s feeds, freshening..." % (user.username, usersubs.count()))
    for sub in usersubs:
        sub.mark_read_date = day_ago
        sub.needs_unread_recalc = True
        sub.save()
        sub.calculate_feed_scores(silent=True)

    socialsubs = MSocialSubscription.objects.filter(user_id=user.pk)
    logging.debug(" ---> %s has %s socialsubs, freshening..." % (user.username, socialsubs.count()))
    for sub in socialsubs:
        sub.mark_read_date = day_ago
        sub.needs_unread_recalc = True
        sub.save()
        sub.calculate_feed_scores(silent=True)


@app.task(name="mark-stories-as-unread")
def MarkStoriesAsUnread(user_id, feed_ids, days):
    UserSubscription.mark_stories_as_unread(user_id, feed_ids, days)


@app.task(name="clean-analytics", time_limit=720 * 10)
def CleanAnalytics():
    total_count = settings.MONGOANALYTICSDB.nbanalytics.feed_fetches.count_documents({})
    logging.debug(" ---> Cleaning analytics... %s feed fetches" % total_count)

    day_ago = datetime.datetime.utcnow() - datetime.timedelta(days=1)
    query = {"date": {"$lt": day_ago}}
    batch_size = 10000
    total_deleted = 0

    while True:
        # Find a batch of document IDs to delete
        docs = list(
            settings.MONGOANALYTICSDB.nbanalytics.feed_fetches.find(query, {"_id": 1}).limit(batch_size)
        )
        if not docs:
            break

        ids = [doc["_id"] for doc in docs]
        result = settings.MONGOANALYTICSDB.nbanalytics.feed_fetches.delete_many({"_id": {"$in": ids}})
        total_deleted += result.deleted_count

        logging.debug(" ---> Deleted %s feed fetches (%s total)" % (result.deleted_count, total_deleted))

        # Brief pause to let MongoDB breathe
        time.sleep(0.5)

    logging.debug(" ---> Finished cleaning analytics, deleted %s feed fetches" % total_deleted)
