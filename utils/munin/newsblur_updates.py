#!/srv/newsblur/venv/newsblur3/bin/python
import redis
from utils.munin.base import MuninGraph
import os
os.environ["DJANGO_SETTINGS_MODULE"] = "newsblur_web.settings"
import django
django.setup()

class NBMuninGraph(MuninGraph):

    @property
    def graph_config(self):
        return {
            'graph_category' : 'NewsBlur',
            'graph_title' : 'NewsBlur Updates',
            'graph_vlabel' : '# of updates',
            'graph_args' : '-l 0',
            'update_queue.label': 'Queued Feeds',
            'feeds_fetched.label': 'Fetched feeds last hour',
            'tasked_feeds.label': 'Tasked Feeds',
            'error_feeds.label': 'Error Feeds',
            'celery_update_feeds.label': 'Celery - Update Feeds',
            'celery_new_feeds.label': 'Celery - New Feeds',
            'celery_push_feeds.label': 'Celery - Push Feeds',
            'celery_work_queue.label': 'Celery - Work Queue',
            'celery_search_queue.label': 'Celery - Search Queue',
        }


    def calculate_metrics(self):
        from django.conf import settings
    
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)

        return {
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

if __name__ == '__main__':
    NBMuninGraph().run()
