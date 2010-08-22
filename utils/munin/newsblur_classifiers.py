#!/usr/bin/env python 

from utils.munin.base import MuninGraph
from apps.analyzer.models import MClassifierFeed, MClassifierAuthor, MClassifierTag, MClassifierTitle

graph_config = {
    'graph_category' : 'NewsBlur',
    'graph_title' : 'NewsBlur Classifiers',
    'graph_vlabel' : '# of classifiers',
    'feeds.label': 'feeds',
    'authors.label': 'authors',
    'tags.label': 'tags',
    'titles.label': 'titles',
}

metrics = {
    'feeds': MClassifierFeed.objects.count(),
    'authors': MClassifierAuthor.objects.count(),
    'tags': MClassifierTag.objects.count(),
    'titles': MClassifierTitle.objects.count(),
}

if __name__ == '__main__':
    MuninGraph(graph_config, metrics).run()
