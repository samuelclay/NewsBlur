import datetime
from celery.task import Task
from utils import log as logging
from django.contrib.auth.models import User
from django.conf import settings
from apps.reader.models import UserSubscription, MUserStory
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

    def run(self, **kwargs):
        logging.debug(" ---> Cleaning analytics... %s page loads and %s feed fetches" % (
            settings.MONGOANALYTICSDB.nbanalytics.page_loads.count(),
            settings.MONGOANALYTICSDB.nbanalytics.feed_fetches.count(),
        ))
        day_ago = datetime.datetime.utcnow() - datetime.timedelta(days=2)
        settings.MONGOANALYTICSDB.nbanalytics.feed_fetches.remove({
            "date": {"$lt": day_ago},
        })
        settings.MONGOANALYTICSDB.nbanalytics.page_loads.remove({
            "date": {"$lt": day_ago},
        })
        
class CleanStories(Task):
    name = 'clean-stories'
    time_limit = 60 * 60 # 1 hour
    
    def run(self, **kwargs):
        days_ago = (datetime.datetime.utcnow() -
                    datetime.timedelta(days=settings.DAYS_OF_UNREAD*5))
        old_stories = MUserStory.objects.filter(read_date__lte=days_ago)
        logging.debug(" ---> Cleaning stories from %s days ago... %s/%s read stories" % (
            settings.DAYS_OF_UNREAD*5,
            MUserStory.objects.count(),
            old_stories.count()
        ))
        for s, story in enumerate(old_stories):
            if (s+1) % 1000 == 0:
                logging.debug(" ---> %s stories removed..." % (s+1))
            story.delete()