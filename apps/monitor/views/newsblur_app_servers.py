import datetime
from django.conf import settings
from django.views import View
from django.shortcuts import render

class AppServers(View):

    def get(self, request):
        data = dict((("%s" % s['_id'].replace('-', ''), s['feeds']) for s in self.stats))
        if self.total:
            data['total'] = self.total[0]['feeds']
        chart_name = "app_servers"
        chart_type = "histogram"
        context = {
            "data": data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        } 
        return render(request, 'monitor/prometheus_data.html', context)
    
    @property
    def stats(self):
        stats = settings.MONGOANALYTICSDB.nbanalytics.page_loads.aggregate([{
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
        stats = settings.MONGOANALYTICSDB.nbanalytics.page_loads.aggregate([{
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
