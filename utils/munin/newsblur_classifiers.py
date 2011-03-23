#!/usr/bin/env python 

from utils.munin.base import MuninGraph

graph_config = {
    'graph_category' : 'NewsBlur',
    'graph_title' : 'NewsBlur Classifiers',
    'graph_vlabel' : '# of classifiers',
    'feeds.label': 'feeds',
    'authors.label': 'authors',
    'tags.label': 'tags',
    'titles.label': 'titles',
}

def calculate_metrics():
    from apps.analyzer.models import MClassifierFeed, MClassifierAuthor, MClassifierTag, MClassifierTitle
    
    return {
        'feeds': MClassifierFeed.objects.count(),
        'authors': MClassifierAuthor.objects.count(),
        'tags': MClassifierTag.objects.count(),
        'titles': MClassifierTitle.objects.count(),
    }

if __name__ == '__main__':
    MuninGraph(graph_config, calculate_metrics).run()
