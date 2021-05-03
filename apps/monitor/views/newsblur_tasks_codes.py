import datetime
from django.conf import settings
from django.shortcuts import render
from django.views import View

class TasksCodes(View):

    def get(self, request):
        data = dict((("_%s" % s['_id'], s['feeds']) for s in self.stats))
        chart_name = "task_codes"
        chart_type = "counter"
        formatted_data = {}
        for k, v in data.items():
            formatted_data[k] = f'{chart_name}{{category="{k}"}} {v}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, 'monitor/prometheus_data.html', context, content_type="text/plain")
    
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
        