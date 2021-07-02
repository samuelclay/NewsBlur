from django.views import View
from django.shortcuts import render
import datetime
from django.conf import settings

class AppTimes(View):

    def get(self, request):
        servers = dict((("%s" % s['_id'], s['page_load']) for s in self.stats))
        data = servers
        chart_name = "app_times"
        chart_type = "counter"

        formatted_data = {}
        for k, v in data.items():
            formatted_data[k] = f'{chart_name}{{app_server="{k}"}} {v}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, 'monitor/prometheus_data.html', context, content_type="text/plain")
    
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
