import datetime
from celery.task import Task
from utils import log as logging
from django.conf import settings

class TaskFeeds(Task):
    name = 'task-feeds'

    def run(self, **kwargs):
        from apps.rss_feeds.models import Feed        
        settings.LOG_TO_STREAM = True
        now = datetime.datetime.utcnow()
        
        # Active feeds
        feeds = Feed.objects.filter(
            next_scheduled_update__lte=now,
            active=True
        ).exclude(
            active_subscribers=0
        ).order_by('?')
        Feed.task_feeds(feeds)
        
        # Mistakenly inactive feeds
        day = now - datetime.timedelta(days=1)
        feeds = Feed.objects.filter(
            last_update__lte=day, 
            queued_date__lte=day,
            min_to_decay__lte=60*24,
            active_subscribers__gte=1
        ).order_by('?')[:20]
        if feeds: Feed.task_feeds(feeds)
        
        week = now - datetime.timedelta(days=7)
        feeds = Feed.objects.filter(
            last_update__lte=week, 
            queued_date__lte=day,
            active_subscribers__gte=1
        ).order_by('?')[:20]
        if feeds: Feed.task_feeds(feeds)

        
class UpdateFeeds(Task):
    name = 'update-feeds'
    max_retries = 0
    ignore_result = True

    def run(self, feed_pks, **kwargs):
        from apps.rss_feeds.models import Feed
        from apps.statistics.models import MStatistics
        
        mongodb_replication_lag = int(MStatistics.get('mongodb_replication_lag', 0))
        compute_scores = bool(mongodb_replication_lag < 60)
        
        options = {
            'fake': bool(MStatistics.get('fake_fetch')),
            'quick': float(MStatistics.get('quick_fetch', 0)),
            'compute_scores': compute_scores,
            'mongodb_replication_lag': mongodb_replication_lag,
        }
        
        if not isinstance(feed_pks, list):
            feed_pks = [feed_pks]
            
        for feed_pk in feed_pks:
            try:
                feed = Feed.objects.get(pk=feed_pk)
                feed.update(**options)
            except Feed.DoesNotExist:
                logging.info(" ---> Feed doesn't exist: [%s]" % feed_pk)
            # logging.debug(' Updating: [%s] %s' % (feed_pks, feed))

class NewFeeds(Task):
    name = 'new-feeds'
    max_retries = 0
    ignore_result = True

    def run(self, feed_pks, **kwargs):
        from apps.rss_feeds.models import Feed
        if not isinstance(feed_pks, list):
            feed_pks = [feed_pks]
        
        options = {
            'force': True,
        }
        for feed_pk in feed_pks:
            feed = Feed.objects.get(pk=feed_pk)
            feed.update(options=options)

class PushFeeds(Task):
    name = 'push-feeds'
    max_retries = 0
    ignore_result = True

    def run(self, feed_id, xml, **kwargs):
        from apps.rss_feeds.models import Feed
        from apps.statistics.models import MStatistics
        
        mongodb_replication_lag = int(MStatistics.get('mongodb_replication_lag', 0))
        compute_scores = bool(mongodb_replication_lag < 60)
        
        options = {
            'feed_xml': xml,
            'compute_scores': compute_scores,
            'mongodb_replication_lag': mongodb_replication_lag,
        }
        feed = Feed.objects.get(pk=feed_id)
        feed.update(options=options)
