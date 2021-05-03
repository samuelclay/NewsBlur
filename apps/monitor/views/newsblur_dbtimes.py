from django.shortcuts import render
from django.views import View

from apps.statistics.models import MStatistics

class DbTimes(View):


    def get(self, request):
        
        data = {
            'sql_avg': MStatistics.get('latest_sql_avg'),
            'mongo_avg': MStatistics.get('latest_mongo_avg'),
            'redis_avg': MStatistics.get('latest_redis_avg'),
            'task_sql_avg': MStatistics.get('latest_task_sql_avg'),
            'task_mongo_avg': MStatistics.get('latest_task_mongo_avg'),
            'task_redis_avg': MStatistics.get('latest_task_redis_avg'),
        }
        chart_name = "db_times"
        chart_type = "counter"

        context = {
            "data": data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, 'monitor/prometheus_data.html', context, content_type="text/plain")
