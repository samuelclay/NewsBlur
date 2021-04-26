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
            'graph_title' : 'NewsBlur Classifiers',
            'graph_vlabel' : '# of classifiers',
            'graph_args' : '-l 0',
            'feeds.label': 'feeds',
            'authors.label': 'authors',
            'tags.label': 'tags',
            'titles.label': 'titles',
        }

    def calculate_metrics(self):
        from apps.analyzer.models import MClassifierFeed, MClassifierAuthor, MClassifierTag, MClassifierTitle

        return {
            'feeds': MClassifierFeed.objects.count(),
            'authors': MClassifierAuthor.objects.count(),
            'tags': MClassifierTag.objects.count(),
            'titles': MClassifierTitle.objects.count(),
        }

if __name__ == '__main__':
    NBMuninGraph().run()
