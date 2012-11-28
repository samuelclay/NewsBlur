#!/usr/bin/env python 
from utils.munin.base import MuninGraph


class NBMuninGraph(MuninGraph):

    @property
    def graph_config(self):
        return {
            'graph_category' : 'NewsBlur',
            'graph_title' : 'NewsBlur Stories',
            'graph_vlabel' : 'Stories',
            'graph_args' : '-l 0',
            'stories.label': 'stories',
            'tags.label': 'tags',
            'authors.label': 'authors',
            'read_stories.label': 'read_stories',
        }

    def calculate_metrics(self):
        from apps.rss_feeds.models import MStory
        from apps.reader.models import MUserStory

        return {
            'stories': MStory.objects().count(),
            'read_stories': MUserStory.objects().count(),
        }

if __name__ == '__main__':
    NBMuninGraph().run()
