#!/usr/bin/env python 
import datetime
from utils.munin.base import MuninGraph
from apps.rss_feeds.models import Feed

graph_config = {
    'graph_category' : 'NewsBlur',
    'graph_title' : 'NewsBlur Updates',
    'graph_vlabel' : '# of updates',
    'update_queue.label': 'Queued Feeds',
    'feeds_fetched.label': 'Fetched feeds last hour',
}

hour_ago = datetime.datetime.utcnow() - datetime.timedelta(hours=1)

metrics = {
    'update_queue': Feed.objects.filter(queued_date__gte=hour_ago).count(),
    'feeds_fetched': Feed.objects.filter(last_update__gte=hour_ago).count()
}

if __name__ == '__main__':
    MuninGraph(graph_config, metrics).run()
