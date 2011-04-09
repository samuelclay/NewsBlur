#!/usr/bin/env python 

from utils.munin.base import MuninGraph

graph_config = {
    'graph_category' : 'NewsBlur',
    'graph_title' : 'NewsBlur Fetching History',
    'graph_vlabel' : 'errors',
    'feed_errors.label': 'Feed Errors',
    'feed_success.label': 'Feed Success',
    'page_errors.label': 'Page Errors',
    'page_success.label': 'Page Success',
}

def calculate_metrics():
    import datetime
    from apps.rss_feeds.models import MFeedFetchHistory, MPageFetchHistory
    
    last_day = datetime.datetime.utcnow() - datetime.timedelta(days=1)
    
    return {
        'feed_errors': MFeedFetchHistory.objects(fetch_date__gte=last_day, status_code__nin=[200, 304]).count(),
        'feed_success': MFeedFetchHistory.objects(fetch_date__gte=last_day, status_code__in=[200, 304]).count(),
        'page_errors': MPageFetchHistory.objects(fetch_date__gte=last_day, status_code__nin=[200, 304]).count(),
        'page_success': MPageFetchHistory.objects(fetch_date__gte=last_day, status_code__in=[200, 304]).count(),
    }

if __name__ == '__main__':
    MuninGraph(graph_config, calculate_metrics).run()
