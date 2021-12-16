from django.shortcuts import render
from django.views import View

from apps.statistics.models import MStatistics

class DbTimes(View):


    def get(self, request):
        
        data = {
            'sql_avg': MStatistics.get('latest_sql_avg'),
            'mongo_avg': MStatistics.get('latest_mongo_avg'),
            'redis_user_avg': MStatistics.get('latest_redis_user_avg'),
            'redis_story_avg': MStatistics.get('latest_redis_story_avg'),
            'redis_session_avg': MStatistics.get('latest_redis_session_avg'),
            'redis_pubsub_avg': MStatistics.get('latest_redis_pubsub_avg'),
            'task_sql_avg': MStatistics.get('latest_task_sql_avg'),
            'task_mongo_avg': MStatistics.get('latest_task_mongo_avg'),
            'task_redis_user_avg': MStatistics.get('latest_task_redis_user_avg'),
            'task_redis_story_avg': MStatistics.get('latest_task_redis_story_avg'),
            'task_redis_session_avg': MStatistics.get('latest_task_redis_session_avg'),
            'task_redis_pubsub_avg': MStatistics.get('latest_task_redis_pubsub_avg'),
        }
        chart_name = "db_times"
        chart_type = "counter"
        formatted_data = {}
        for k, v in data.items():
            formatted_data[k] = f'{chart_name}{{db="{k}"}} {v}'
        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, 'monitor/prometheus_data.html', context, content_type="text/plain")
