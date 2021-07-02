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
            'graph_title' : 'NewsBlur Loadtimes',
            'graph_vlabel' : 'Loadtimes (seconds)',
            'graph_args' : '-l 0',
            'feed_loadtimes_avg_hour.label': 'Feed Loadtimes Avg (Hour)',
            'feeds_loaded_hour.label': 'Feeds Loaded (Hour)',
        }

    def calculate_metrics(self):
        from apps.statistics.models import MStatistics
        
        return {
            'feed_loadtimes_avg_hour': MStatistics.get('latest_avg_time_taken'),
            'feeds_loaded_hour': MStatistics.get('latest_sites_loaded'),
        }

if __name__ == '__main__':
    NBMuninGraph().run()
