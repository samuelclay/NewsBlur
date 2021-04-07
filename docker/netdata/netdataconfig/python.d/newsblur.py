from random import SystemRandom
from bases.FrameworkServices.SimpleService import SimpleService
import os
import requests
        
MONITOR_URL = os.getenv("MONITOR_URL")
if MONITOR_URL == "https://haproxy:443/monitor":
    verify = False
else:
    verify = False


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

def call_monitor(endpoint):
    uri = MONITOR_URL + endpoint
    res = requests.get(uri, verify=verify)
    return res.json()
     
class Service(SimpleService):
    def __init__(self, configuration=None, name=None):
        SimpleService.__init__(self, configuration=configuration, name=name)
        self.order = [
            "app-servers"
        ]

        self.definitions = {
            'app-servers': {
                # 'options': [name, title, units, family, context, charttype]
                'options': [None, 'App Server Page Loads', None, None, 'context', 'stacked'], # line indicates that it is a line graph
                'lines': [[key] for key in call_monitor(endpoints['app_servers'])] #must be a valid key in 'get_data()'s return 
                
            }
        }
        self.random = SystemRandom()

    @staticmethod
    def check():
        return True

    def get_data(self):
        data = {}
        api_data = call_monitor(endpoints['app_servers'])

        for key in call_monitor(endpoints['app_servers']).keys():
            dimension_id = key

            if dimension_id not in self.charts['app-servers']:
                self.charts['app-servers'].add_dimension([dimension_id])

            data[dimension_id] = api_data[dimension_id]

        return data
