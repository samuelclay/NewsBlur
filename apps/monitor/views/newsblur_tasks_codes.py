import datetime
from django.conf import settings
from django.http import JsonResponse
from django.views import View

class TasksCodes(View):

    def get(self, request):
        servers = dict((("_%s" % s['_id'], s['feeds']) for s in self.stats))
        
        return JsonResponse(servers)
    
    @property
    def stats(self):        
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
        