#!/usr/bin/env python 
from utils.munin.base import MuninGraph

class NBMuninGraph(MuninGraph):

    @property
    def graph_config(self):
        graph = {
            'graph_category' : 'NewsBlur',
            'graph_title' : 'NewsBlur Task Codes',
            'graph_vlabel' : 'Status codes on feed fetch',
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
        
        return stats['result']
        

if __name__ == '__main__':
    NBMuninGraph().run()
