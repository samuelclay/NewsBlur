#!/usr/bin/env python 
import redis
from utils.munin.base import MuninGraph

graph_config = {
    'graph_category' : 'NewsBlur',
    'graph_title' : 'NewsBlur Updates',
    'graph_vlabel' : '# of updates',
    'update_queue.label': 'Queued Feeds last hour',
    'feeds_fetched.label': 'Fetched feeds last hour',
    'celery_update_feeds.label': 'Celery - Update Feeds',
    'celery_new_feeds.label': 'Celery - New Feeds',
}


def calculate_metrics():
    import datetime
    import commands
    from apps.rss_feeds.models import Feed
    from django.conf import settings
    
    hour_ago = datetime.datetime.utcnow() - datetime.timedelta(hours=1)
    r = redis.Redis(connection_pool=settings.REDIS_POOL)    

    return {
        'update_queue': Feed.objects.filter(queued_date__gte=hour_ago).count(),
        'feeds_fetched': Feed.objects.filter(last_update__gte=hour_ago).count(),
        'celery_update_feeds': r.llen("update_feeds"),
        'celery_new_feeds': r.llen("new_feeds"),
    }

if __name__ == '__main__':
    MuninGraph(graph_config, calculate_metrics).run()
