#!/usr/bin/env python 

from utils.munin.base import MuninGraph

class NBMuninGraph(MuninGraph):

    @property
    def graph_config(self):
        return {
            'graph_category' : 'NewsBlur',
            'graph_title' : 'NewsBlur Fetching History',
            'graph_vlabel' : 'errors',
            'graph_args' : '-l 0',
            # 'feed_errors.label': 'Feed Errors',
            'feed_success.label': 'Feed Success',
            # 'page_errors.label': 'Page Errors',
            'page_success.label': 'Page Success',
        }

    def calculate_metrics(self):
        from apps.statistics.models import MStatistics
        statistics = MStatistics.all()
    
        return {
            'feed_success': statistics['feeds_fetched'],
            'page_success': statistics['pages_fetched'],
        }

if __name__ == '__main__':
    NBMuninGraph().run()
