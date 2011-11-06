from celery.task import Task
from utils import log as logging
from django.conf import settings

class UpdateFeeds(Task):
    name = 'update-feeds'
    max_retries = 0
    ignore_result = True

    def run(self, feed_pks, **kwargs):
        from apps.rss_feeds.models import Feed
        if not isinstance(feed_pks, list):
            feed_pks = [feed_pks]
            
        import pymongo
        db = pymongo.Connection(settings.MONGODB_SLAVE['host'], slave_okay=True, replicaset='nbset').newsblur

        for feed_pk in feed_pks:
            try:
                feed = Feed.objects.get(pk=feed_pk)
                feed.update(slave_db=db)
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
