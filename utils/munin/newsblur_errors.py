#!/srv/newsblur/venv/newsblur3/bin/python

from utils.munin.base import MuninGraph
import os
os.environ["DJANGO_SETTINGS_MODULE"] = "newsblur_web.settings"
import django
django.setup()

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
            # 'page_success.label': 'Page Success',
        }

    def calculate_metrics(self):
        from apps.statistics.models import MStatistics
        statistics = MStatistics.all()
    
        return {
            'feed_success': statistics['feeds_fetched'],
        }

if __name__ == '__main__':
    NBMuninGraph().run()
