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
    from apps.statistics.models import MStatistics
    statistics = MStatistics.all()
    
    return {
        'feed_success': statistics['feeds_fetched']
    }

if __name__ == '__main__':
    MuninGraph(graph_config, calculate_metrics).run()
