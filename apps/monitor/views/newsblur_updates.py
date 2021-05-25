import redis

from django.conf import settings
from django.shortcuts import render
from django.views import View

class Updates(View):

    def get(self, request):    
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)

        data = {
            'update_queue': r.scard("queued_feeds"),
            'feeds_fetched': r.zcard("fetched_feeds_last_hour"),
            'tasked_feeds': r.zcard("tasked_feeds"),
            'error_feeds': r.zcard("error_feeds"),
            'celery_update_feeds': r.llen("update_feeds"),
            'celery_new_feeds': r.llen("new_feeds"),
            'celery_push_feeds': r.llen("push_feeds"),
            'celery_work_queue': r.llen("work_queue"),
            'celery_search_queue': r.llen("search_indexer"),
        }
        chart_name = "updates"
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

