"""Reader tasks: periodic maintenance for homepage freshening and analytics cleanup."""

import datetime
import time

from django.conf import settings
from django.contrib.auth.models import User

from apps.reader.models import UserSubscription
from apps.social.models import MSocialSubscription
from newsblur_web.celeryapp import app
from utils import log as logging


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
