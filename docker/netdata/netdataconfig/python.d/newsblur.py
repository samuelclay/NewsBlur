from random import SystemRandom
from bases.FrameworkServices.SimpleService import SimpleService
import os
import requests

class Monitor():
        
    MONITOR_URL = os.getenv("MONITOR_URL")
    if MONITOR_URL == "https://haproxy:443/monitor":
        verify = False
    else:
        verify = False

    def __init__(self):

        endpoints = {
            "app_servers": "/app-servers",
            "app_times": "/app-times",
            "classifiers": "/classifiers",
            "db_times": "/db-times",
            "errors": "/errors",
            "feed_counts": "/feed-counts",
            "feeds": "/feeds",
            "load_times": "/load-times",
            "stories": "/stories",
            "task_codes": "/task-codes",
            "task_pipeline": "/task-pipeline",
            "task_servers": "/task-servers",
            "task_times": "/task-times",
            "updates": "/updates",
            "users": "/users",
        }

        for name, endpoint in endpoints.items():
            setattr(self, name, self.call_monitor(endpoint))

    def call_monitor(self, endpoint):
        uri = self.MONITOR_URL + endpoint
        res = requests.get(uri, verify=self.verify)
        return res.json()
        
priority = 90000

ORDER = [
    'app-servers',
    'app-times',
    'classifiers'
]

CHARTS = {
    'app-servers': {
        # 'options': [name, title, units, family, context, charttype]
        'options': [None, 'App Server Page Loads', None, None, 'context', 'stacked'], # line indicates that it is a line graph
        'lines': [
            ['app servers total'] #must be a valid key in 'get_data()'s return 
        ]
    },
    'app-times': {
        'options': [None, 'NewsBlur App Times', None, None, 'context', 'stacked'], # line indicates that it is a line graph
        'lines': [
            ['app times total']
        ]
    },
    'classifiers': {
        'options': [None, 'Classifiers', None, None, 'context', 'stacked'], # line indicates that it is a line graph
        'lines': [
            ['classifiers feeds']
        ]
    }
}


class Service(SimpleService):
    def __init__(self, configuration=None, name=None):
        SimpleService.__init__(self, configuration=configuration, name=name)
        self.order = ORDER
        self.definitions = CHARTS
        self.random = SystemRandom()
        self.monitor = Monitor()

    @staticmethod
    def check():
        return True

    def get_data(self):

        data = dict()
        charts = {
            "app-servers": "app servers total",
            "app-times": "app times total",
            "classifiers": "classifiers feeds"
        }
        for chart, dimension_id in charts.items():

            if dimension_id not in self.charts[chart]:
                self.charts[chart].add_dimension([dimension_id])

            data[dimension_id] = self.random.randint(0, 100)
        return data