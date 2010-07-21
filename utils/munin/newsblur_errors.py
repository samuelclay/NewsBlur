#!/usr/bin/env python 

from utils.munin.base import MuninGraph
from apps.rss_feeds.models import FeedFetchHistory, PageFetchHistory
import datetime


graph_config = {
    'graph_category' : 'NewsBlur',
    'graph_title' : 'NewsBlur Users',
    'graph_vlabel' : 'users',
    'all.label': 'all',
}

last_day = datetime.datetime.now() - datetime.timedelta(days=1)

metrics = {
    'feed_errors': FeedFetchHistory.objects.filter(fetch_date__gte=last_day).exclude(status_code__in=[200, 304]).count(),
    'feed_success': FeedFetchHistory.objects.filter(fetch_date__gte=last_day).filter(status_code__in=[200, 304]).count(),
    'page_errors': PageFetchHistory.objects.filter(fetch_date__gte=last_day).exclude(status_code__in=[200, 304]).count(),
    'page_success': PageFetchHistory.objects.filter(fetch_date__gte=last_day).filter(status_code__in=[200, 304]).count(),
}

if __name__ == '__main__':
    MuninGraph(graph_config, metrics).run()
