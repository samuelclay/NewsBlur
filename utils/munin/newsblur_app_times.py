#!/srv/newsblur/venv/newsblur3/bin/python
from utils.munin.base import MuninGraph

class NBMuninGraph(MuninGraph):

    @property
    def graph_config(self):
        graph = {
            'graph_category' : 'NewsBlur',
            'graph_title' : 'NewsBlur App Server Times',
            'graph_vlabel' : 'Page load time / server',
            'graph_args' : '-l 0',
        }

        stats = self.stats
        graph['graph_order'] = ' '.join(sorted(s['_id'] for s in stats))
        graph.update(dict((("%s.label" % s['_id'], s['_id']) for s in stats)))
        graph.update(dict((("%s.draw" % s['_id'], 'LINE1') for s in stats)))

        return graph

    def calculate_metrics(self):
        servers = dict((("%s" % s['_id'], s['page_load']) for s in self.stats))

        return servers
    
    @property
    def stats(self):
        import datetime
        import os
        os.environ["DJANGO_SETTINGS_MODULE"] = "newsblur_web.settings"
        from django.conf import settings
        
        stats = settings.MONGOANALYTICSDB.nbanalytics.page_loads.aggregate([{
            "$match": {
                "date": {
                    "$gt": datetime.datetime.now() - datetime.timedelta(minutes=5),
                },
            },
        }, {
            "$group": {
                "_id"   : "$server",
                "page_load" : {"$avg": "$page_load"},
            },
        }])
        
        return list(stats)
        

if __name__ == '__main__':
    NBMuninGraph().run()
