#!/usr/bin/env python 
from utils.munin.base import MuninGraph

graph_config = {
    'graph_category' : 'NewsBlur',
    'graph_title' : 'NewsBlur Updates',
    'graph_vlabel' : '# of updates',
    'update_queue.label': 'Queued Feeds last hour',
    'feeds_fetched.label': 'Fetched feeds last hour',
    'celery_update_feeds.label': 'Celery - Queued Feeds',
    'celery_update_feeds.label': 'Celery - Queued Feeds',
}


def calculate_metrics():
    import datetime
    import commands
    from apps.rss_feeds.models import Feed
    
    hour_ago = datetime.datetime.utcnow() - datetime.timedelta(hours=1)
    update_feeds_query = "ssh db01 \"sudo rabbitmqctl list_queues -p newsblurvhost | grep %s\" | awk '{print $2}'"
    
    return {
        'update_queue': Feed.objects.filter(queued_date__gte=hour_ago).count(),
        'feeds_fetched': Feed.objects.filter(last_update__gte=hour_ago).count(),
        'celery_update_feeds': commands.getoutput(update_feeds_query % 'update_feeds'),
        'celery_new_feeds': commands.getoutput(update_feeds_query % 'new_feeds'),
    }

if __name__ == '__main__':
    MuninGraph(graph_config, calculate_metrics).run()
