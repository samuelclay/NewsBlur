#!/usr/bin/env python 

from utils.munin.base import MuninGraph
from apps.analyzer.models import ClassifierFeed, ClassifierAuthor, ClassifierTag, ClassifierTitle

graph_config = {
    'graph_category' : 'Protopub',
    'graph_title' : 'Protopub Classifiers',
    'graph_vlabel' : '# of classifiers',
    'feeds.label': 'feeds',
    'authors.label': 'authors',
    'tags.label': 'tags',
    'titles.label': 'titles',
}

metrics = {
    'feeds': ClassifierFeed.objects.count(),
    'authors': ClassifierAuthor.objects.count(),
    'tags': ClassifierTag.objects.count(),
    'titles': ClassifierTitle.objects.count(),
}

if __name__ == '__main__':
    MuninGraph(graph_config, metrics).run()
