import datetime

from django.conf import settings
from django.http import JsonResponse
from django.views import View

class TasksPipeline(View):

    def get(self, request):
        return JsonResponse(self.stats)
    
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
                "_id":          1,
                "feed_fetch":   {"$avg": "$feed_fetch"},
                "feed_process": {"$avg": "$feed_process"},
                "page":         {"$avg": "$page"},
                "icon":         {"$avg": "$icon"},
                "total":        {"$avg": "$total"},
            },
        }])
        stats = list(stats)
        if stats:
            print(stats)
            return list(stats)[0]
        else:
            return {}
