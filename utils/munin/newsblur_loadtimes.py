#!/usr/bin/env python 

from utils.munin.base import MuninGraph
from apps.rss_feeds.models import FeedLoadtime
from django.db.models import Avg, Min, Max
import datetime


graph_config = {
    'graph_category' : 'NewsBlur',
    'graph_title' : 'NewsBlur Loadtimes',
    'graph_vlabel' : 'Loadtimes (seconds)',
    'feed_loadtimes_avg_hour.label': 'Feed Loadtimes Avg (Hour)',
    'feed_loadtimes_min_hour.label': 'Feed Loadtimes Min (Hour)',
    'feed_loadtimes_max_hour.label': 'Feed Loadtimes Max (Hour)',
    'feed_loadtimes_avg_day.label': 'Feed Loadtimes Avg (Day)',
    'feed_loadtimes_min_day.label': 'Feed Loadtimes Min (Day)',
    'feed_loadtimes_max_day.label': 'Feed Loadtimes Max (Day)',
}

day_ago = datetime.datetime.now() - datetime.timedelta(days=1)
hour_ago = datetime.datetime.now() - datetime.timedelta(minutes=60)

averages = dict(avg=Avg('loadtime'), max=Max('loadtime'), min=Min('loadtime'))
day = FeedLoadtime.objects.filter(date_accessed__gte=day_ago).aggregate(**averages)
hour = FeedLoadtime.objects.filter(date_accessed__gte=hour_ago).aggregate(**averages)

metrics = {
    'feed_loadtimes_avg_hour': hour['avg'],
    'feed_loadtimes_min_hour': hour['min'],
    'feed_loadtimes_max_hour': hour['max'],
    'feed_loadtimes_avg_day': day['avg'],
    'feed_loadtimes_min_day': day['min'],
    'feed_loadtimes_max_day': day['max'],
}

if __name__ == '__main__':
    MuninGraph(graph_config, metrics).run()
