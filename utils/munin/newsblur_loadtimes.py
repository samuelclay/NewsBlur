#!/usr/bin/env python 
from utils.munin.base import MuninGraph
from django.conf import settings
import datetime

class NBMuninGraph(MuninGraph):

    @property
    def graph_config(self):
        return {
            'graph_category' : 'NewsBlur',
            'graph_title' : 'NewsBlur Loadtimes',
            'graph_vlabel' : 'Loadtimes (seconds)',
            'feed_loadtimes_avg_hour.label': 'Feed Loadtimes Avg (Hour)',
            'feed_loadtimes_min_hour.label': 'Feed Loadtimes Min (Hour)',
            'feed_loadtimes_max_hour.label': 'Feed Loadtimes Max (Hour)',
            'feeds_loaded_hour.label': 'Feeds Loaded (Hour)',
        }

    def calculate_metrics(self):
        hour_ago = datetime.datetime.utcnow() - datetime.timedelta(minutes=60)
        times = settings.MONGOANALYTICSDB.nbanalytics.page_loads.aggregate([{
            "$match": {
                "date": {
                    "$gte": hour_ago,
                },
                "path": {
                    "$in": [
                        "/reader/feed/",
                        "/social/stories/",
                        "/reader/river_stories/",
                        "/social/river_stories/",
                    ]
                }
            },
        }, {
            "$group": {
                "_id"   : 1,
                "count" : {"$sum": 1},
                "avg"   : {"$avg": "$duration"},
                "min"   : {"$min": "$duration"},
                "max"   : {"$max": "$duration"},
            },
        }])
        
        load_avg = 0
        load_min = 0
        load_max = 0
        load_count = 0
        if times['result']:
            load_avg = times['result'][0]['avg']
            load_min = times['result'][0]['min']
            load_max = times['result'][0]['max']
            load_count = times['result'][0]['count']
        
        return {
            'feed_loadtimes_avg_hour': load_avg,
            'feed_loadtimes_min_hour': load_min,
            'feed_loadtimes_max_hour': load_max,
            'feeds_loaded_hour': load_count,
        }

if __name__ == '__main__':
    NBMuninGraph().run()
