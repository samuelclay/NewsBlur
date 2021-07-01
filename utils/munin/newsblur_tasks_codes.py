#!/srv/newsblur/venv/newsblur3/bin/python
from utils.munin.base import MuninGraph
import os
os.environ["DJANGO_SETTINGS_MODULE"] = "newsblur_web.settings"

class NBMuninGraph(MuninGraph):

    @property
    def graph_config(self):
        graph = {
            'graph_category' : 'NewsBlur',
            'graph_title' : 'NewsBlur Task Codes',
            'graph_vlabel' : 'Status codes on feed fetch',
            'graph_args' : '-l 0',
        }
        stats = self.stats
        graph.update(dict((("_%s.label" % s['_id'], s['_id']) for s in stats)))
        graph['graph_order'] = ' '.join(sorted(("_%s" % s['_id']) for s in stats))

        return graph

    def calculate_metrics(self):
        servers = dict((("_%s" % s['_id'], s['feeds']) for s in self.stats))
        
        return servers
    
    @property
    def stats(self):
        import datetime
        from django.conf import settings
        
        stats = settings.MONGOANALYTICSDB.nbanalytics.feed_fetches.aggregate([{
            "$match": {
                "date": {
                    "$gt": datetime.datetime.now() - datetime.timedelta(minutes=5),
                },
            },
        }, {
            "$group": {
                "_id"   : "$feed_code",
                "feeds" : {"$sum": 1},
            },
        }])
        
        return list(stats)
        

if __name__ == '__main__':
    NBMuninGraph().run()
