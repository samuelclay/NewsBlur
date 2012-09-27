#!/usr/bin/env python 
from utils.munin.base import MuninGraph

class NBMuninGraph(MuninGraph):

    @property
    def graph_config(self):
        graph = {
            'graph_category' : 'NewsBlur',
            'graph_title' : 'NewsBlur Paths',
        }
        servers = dict((("%s.label" % s['_id'], s['_id']) for s in self.stats))
        graph.update(servers)
        return graph

    def calculate_metrics(self):
        servers = dict((("%s" % s['_id'], s['feeds']) for s in self.stats))
        return servers
    
    @property
    def stats(self):
        import datetime
        from django.conf import settings
        
        stats = settings.MONGOANALYTICSDB.nbanalytics.page_loads.aggregate([{
            "$match": {
                "date": {
                    "$gt": datetime.datetime.now() - datetime.timedelta(minutes=5),
                },
            },
        }, {
            "$group": {
                "_id"   : "$path",
                "path" : {"$sum": 1},
            },
        }])
        
        return stats['result']
        

if __name__ == '__main__':
    NBMuninGraph().run()
