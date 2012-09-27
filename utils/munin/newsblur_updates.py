#!/usr/bin/env python 
import redis
from utils.munin.base import MuninGraph

class NBMuninGraph(MuninGraph):

    @property
    def graph_config(self):
        return {
            'graph_category' : 'NewsBlur',
            'graph_title' : 'NewsBlur Updates',
            'graph_vlabel' : '# of updates',
            'update_queue.label': 'Queued Feeds last hour',
            'feeds_fetched.label': 'Fetched feeds last hour',
            'celery_update_feeds.label': 'Celery - Update Feeds',
            'celery_new_feeds.label': 'Celery - New Feeds',
            'celery_push_feeds.label': 'Celery - Push Feeds',
            'celery_work_queue.label': 'Celery - Work Queue',
        }


    def calculate_metrics(self):
        import datetime
        from apps.rss_feeds.models import Feed
        from django.conf import settings
    
        hour_ago = datetime.datetime.utcnow() - datetime.timedelta(hours=1)
        r = redis.Redis(connection_pool=settings.REDIS_POOL)    

        return {
            'update_queue': Feed.objects.filter(queued_date__gte=hour_ago).count(),
            'feeds_fetched': Feed.objects.filter(last_update__gte=hour_ago).count(),
            'celery_update_feeds': r.llen("update_feeds"),
            'celery_new_feeds': r.llen("new_feeds"),
            'celery_push_feeds': r.llen("push_feeds"),
            'celery_work_queue': r.llen("work_queue"),
        }

if __name__ == '__main__':
    NBMuninGraph().run()
