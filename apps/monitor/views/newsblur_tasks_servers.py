import datetime

from django.conf import settings
from django.http import JsonResponse
from django.views import View

class TasksServers(View):

    def get(self, request):
        servers = dict((("%s" % s['_id'].replace('-', ''), s['feeds']) for s in self.stats))
        servers['total'] = self.total[0]['feeds']
        return JsonResponse(servers)
    
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
