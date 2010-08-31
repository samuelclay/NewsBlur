from celery.task import Task
from apps.rss_feeds.models import Feed

class RefreshFeed(Task):
    name = 'refresh-feed'
    max_retries = 0

    def run_task(self, feed_pk, **kwargs):
        feed = Feed.objects.get(pk=feed_pk)
        feed.update()

