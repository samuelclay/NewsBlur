#!/usr/bin/env python 

from utils.munin.base import MuninGraph
from django.contrib.auth.models import User

graph_config = {
    'graph_category' : 'NewsBlur',
    'graph_title' : 'NewsBlur Users',
    'graph_vlabel' : 'users',
    'all.label': 'all',
}

metrics = {
    'all': User.objects.count(),
}

if __name__ == '__main__':
    MuninGraph(graph_config, metrics).run()
