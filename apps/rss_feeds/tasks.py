from celery.task import Task
from utils import log as logging

class UpdateFeeds(Task):
    name = 'update-feeds'
    max_retries = 0
    ignore_result = True

    def run(self, feed_pks, **kwargs):
        from apps.rss_feeds.models import Feed
        if not isinstance(feed_pks, list):
            feed_pks = [feed_pks]
            
        for feed_pk in feed_pks:
            try:
                feed = Feed.objects.get(pk=feed_pk)
                feed.update()
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
            
        for feed_pk in feed_pks:
            feed = Feed.objects.get(pk=feed_pk)
            feed.update()
