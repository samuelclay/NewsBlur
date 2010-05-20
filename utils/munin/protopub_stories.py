#!/usr/bin/env python 

from utils.munin.base import MuninGraph
from apps.rss_feeds.models import Story, Tag, StoryAuthor
from apps.reader.models import UserStory

graph_config = {
    'graph_category' : 'Protopub',
    'graph_title' : 'Protopub Stories',
    'graph_vlabel' : 'Stories',
    'stories.label': 'stories',
    'tags.label': 'tags',
    'authors.label': 'authors',
    'read_stories.label': 'read_stories',
}

metrics = {
    'stories': Story.objects.count(),
    'tags': Tag.objects.count(),
    'authors': StoryAuthor.objects.count(),
    'read_stories': UserStory.objects.count(),
}

if __name__ == '__main__':
    MuninGraph(graph_config, metrics).run()
