from django.views import View
from django.shortcuts import render
import datetime
from django.conf import settings

class AppTimes(View):

    def get(self, request):
        servers = dict((("%s" % s['_id'], s['page_load']) for s in self.stats))
        data = servers
        chart_name = "app_times"
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
