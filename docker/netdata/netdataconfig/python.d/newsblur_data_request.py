import os
import requests 
from bases.FrameworkServices.SimpleService import SimpleService

CHART_REQUEST_CONFIG = {
    "app-servers": {
        "url": "/app-servers" ,
        "keys": [
            "total"
        ],
    },
    "app-times": {
        "url": "/app-times",
        "keys": [
            
        ]
    },
    "classifiers": {
        "url": "/classifiers",
        "keys": [
            "feeds",
            "authors",
            "tags",
            "titles",
        ]
    },
    "db-times": {
        "url": "/db-times",
        "keys": [
            "sql_avg",
            "mongo_avg",
            "redis_avg",
            "task_sql_avg",
            "task_mongo_avg",
            "task_redis_avg",
        ]

    },
    "errors": {
        "url": "/errors",
        "keys": [
            "feed_success"
        ]
    },
    "feed-counts": {
        "url": "/feed-counts",
        "keys": [
            "scheduled_feeds",
            "exception_feeds",
            "exception_pages",
            "duplicate_feeds",
            "active_feeds",
            "push_feeds",
        ]
    },
    "feeds": {
        "url": "/feeds",
        "keys": [
            "feeds",
            "subscriptions",
            "profiles",
            "social_subscriptions"
        ]
    },
    "load-times": {
        "url": "/load-times",
        "keys": [
            "feed_loadtimes_avg_hour",
            "feeds_loaded_hour"
        ]
    },
    "stories": {
        "url": "/stories",
        "keys": [
            "stories",
            "starred stories"
        ],
    },
    "task-codes": {
        "url": "/task-codes",
        "keys": [
            #TODO
        ]
    },
    "task-pipeline": {
        "url": "/task-pipeline",
        "keys": [
            #TODO
        ]
    },
    "task-servers": {
        "url": "/task-servers",
        "keys": [
            "total"
        ]
    },
    "task-times": {
        "url": "/task-times",
        "keys": [
            #TODO
        ]
    },
    "updates": {
        "url": "/updates",
        "keys": {
            "update_queue",
            "feeds_fetched",
            "tasked_feeds",
            "error_feeds",
            "celery_update_feeds",
            "celery_new_feeds",
            "celery_push_feeds",
            "celery_work_queue",
            "celery_search_queue",
        }
    },
    "users": {
        "url": "/users",
        "keys": [
            "all",
            "monthly",
            "daily",
            "premium",
            "queued",
        ]
    }
}


class Service(SimpleService):

    def order_charts(self):
        chart_order = []
        for chart in CHART_REQUEST_CONFIG.keys():
            chart_order.append
        return chart_order
    
    def build_charts(self):
        """
        every key gets its own chart
        """
        chart_definitions = {}
        for service, chart_data in CHART_REQUEST_CONFIG.items():
            for key in chart_data.get("keys"):
                chart_name = f"{service}_{key}"
                title = chart_data.get("title")
                units = chart_data.get("units", chart_name)
                family = chart_data.get("family", chart_name)
                context = chart_data.get("context", chart_name)
                chart_type = chart_data.get("chart_type", "line")
                lines = chart_data.get("lines")

                chart_definitions[chart_name] = {
                    "options": [chart_name, title, units, family, context, chart_type],
                    "lines": [chart_name]
                }

        return chart_definitions

    def __init__(self, configuration=None, name=None):
        SimpleService.__init__(self, configuration=configuration, name=name)
        self.priority = 90000

        self.order = self.order_charts()

        self.definitions = self.build_charts()

    def get_data(self):
        """
        Makes requests givven the CHART_REQUEST_CONFIG
        and returns dict of data for charts. For example
        a config like
        {
            "app-servers": {
                "url": "/app-servers" ,
                "keys": [
                    "total"
                ]
        }

        would return
        
        {
            app-servers_total: 0
        }

        """
        MONITOR_URL = os.getenv("MONITOR_URL")
        if MONITOR_URL == "https://haproxy:443/monitor":
            verify = False
        else:
            verify = True
        data = {}
        for service, chart_data in CHART_REQUEST_CONFIG.items():
            res = requests.get(MONITOR_URL + chart_data["url"], verify=verify)
            res_data = res.json()
            for key in chart_data['keys']:
                data[f"{service}_{key}"] = res_data.get(key)

        return data  


