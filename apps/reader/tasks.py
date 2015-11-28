import datetime
from celery.task import Task
from utils import log as logging
from django.contrib.auth.models import User
from django.conf import settings
from apps.reader.models import UserSubscription
from apps.social.models import MSocialSubscription


class FreshenHomepage(Task):
    name = 'freshen-homepage'

    def run(self, **kwargs):
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

class CleanAnalytics(Task):
    name = 'clean-analytics'
    hard = 720*10

    def run(self, **kwargs):
        logging.debug(" ---> Cleaning analytics... %s feed fetches" % (
            settings.MONGOANALYTICSDB.nbanalytics.feed_fetches.count(),
        ))
        day_ago = datetime.datetime.utcnow() - datetime.timedelta(days=1)
        settings.MONGOANALYTICSDB.nbanalytics.feed_fetches.remove({
            "date": {"$lt": day_ago},
        })
