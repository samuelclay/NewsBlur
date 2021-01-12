#!/srv/newsblur/venv/newsblur3/bin/python
from utils.munin.base import MuninGraph
import datetime
import os
os.environ["DJANGO_SETTINGS_MODULE"] = "newsblur_web.settings"
from django.conf import settings


class NBMuninGraph(MuninGraph):

    @property
    def graph_config(self):
        graph = {
            'graph_category' : 'NewsBlur',
            'graph_title'    : 'NewsBlur Task Server Fetches',
            'graph_vlabel'   : '# of fetches / server',
            'graph_args'     : '-l 0',
            'total.label'    : 'total',
            'total.draw'     : 'LINE1',
        }
        stats = self.stats
        graph.update(dict((("%s.label" % s['_id'].replace('-', ''), s['_id']) for s in stats)))
        graph.update(dict((("%s.draw" % s['_id'].replace('-', ''), "AREASTACK") for s in stats)))
        graph['graph_order'] = ' '.join(sorted(s['_id'].replace('-', '') for s in stats))
        return graph

    def calculate_metrics(self):
        servers = dict((("%s" % s['_id'].replace('-', ''), s['feeds']) for s in self.stats))
        servers['total'] = self.total[0]['feeds']
        return servers
    
    @property
    def stats(self):
        stats = settings.MONGOANALYTICSDB.nbanalytics.feed_fetches.aggregate([{
            "$match": {
                "date": {
                    "$gte": datetime.datetime.now() - datetime.timedelta(minutes=5),
                },
            },
        }, {
            "$group": {
                "_id"   : "$server",
                "feeds" : {"$sum": 1},
            },
        }])
        
        return list(stats)
        
    @property
    def total(self):
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
                "_id"   : 1,
                "feeds" : {"$sum": 1},
            },
        }])
        
        return list(stats)
        

if __name__ == '__main__':
    NBMuninGraph().run()
