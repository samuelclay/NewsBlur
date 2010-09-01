from celery.task import Task
from apps.rss_feeds.models import Feed

class RefreshFeed(Task):
    name = 'refresh-feed'
    max_retries = 0
    ignore_result = True

    def run(self, feed_pks, **kwargs):
        if not isinstance(feed_pks, list):
            feed_pks = [feed_pks]
            
        for feed_pk in feed_pks:
            feed = Feed.objects.get(pk=feed_pk)
            feed.update()

