#!/usr/bin/env python 

from utils.munin.base import MuninGraph
from apps.rss_feeds.models import FeedLoadtime
from django.db.models import Avg, Min, Max, Count
import datetime


graph_config = {
    'graph_category' : 'NewsBlur',
    'graph_title' : 'NewsBlur Loadtimes',
    'graph_vlabel' : 'Loadtimes (seconds)',
    'feed_loadtimes_avg_hour.label': 'Feed Loadtimes Avg (Hour)',
    'feed_loadtimes_min_hour.label': 'Feed Loadtimes Min (Hour)',
    'feed_loadtimes_max_hour.label': 'Feed Loadtimes Max (Hour)',
    'feeds_loaded_hour.label': 'Feeds Loaded (Hour)',
}

hour_ago = datetime.datetime.utcnow() - datetime.timedelta(minutes=60)

averages = dict(avg=Avg('loadtime'), max=Max('loadtime'), min=Min('loadtime'), count=Count('loadtime'))
hour = FeedLoadtime.objects.filter(date_accessed__gte=hour_ago).aggregate(**averages)

metrics = {
    'feed_loadtimes_avg_hour': hour['avg'],
    'feed_loadtimes_min_hour': hour['min'],
    'feed_loadtimes_max_hour': hour['max'],
    'feeds_loaded_hour': hour['count'],
}

if __name__ == '__main__':
    MuninGraph(graph_config, metrics).run()
