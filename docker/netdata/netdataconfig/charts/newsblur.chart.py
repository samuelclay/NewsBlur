from bases.FrameworkServices.SimpleService import SimpleService
import os
import requests
import time

requests.packages.urllib3.disable_warnings() 
MONITOR_URL = os.getenv("MONITOR_URL")
STAGING = os.getenv("STAGING")

if MONITOR_URL == "https://haproxy/monitor" or STAGING:
    verify = False
else:
    verify = True


def call_monitor(endpoint):
    uri = MONITOR_URL + endpoint
    res = requests.get(uri, verify=verify)
    try:
        data = res.json()
        if data.get("total"):
            del data['total']
        return data
    except:
        return {}

class Service(SimpleService):
    def __init__(self, configuration=None, name=None):
        SimpleService.__init__(self, configuration=configuration, name=name)
        self.title = self.configuration.get("title", "")
        self.chart_name = self.configuration.get("chart_name")
        self.endpoint = self.configuration.get("endpoint")
        self.context = self.configuration.get("context")
        self.chart_type = self.configuration.get("type", "line")
        self.order = [
            self.configuration.get("chart_name"), "data retrieval time"
        ]
        self.monitor_data = call_monitor(self.endpoint)
        self.definitions = {
            self.chart_name: {
                # 'options': [name, title, units, family, context, charttype]
                'options': [None, self.title, None, None, self.context, self.chart_type], # line indicates that it is a line graph
                'lines': [[key] for key in self.monitor_data] #must be a valid key in 'get_data()'s return 
                
            },
            "data retrieval time": {
                'options': [None, self.title + "Data Retrieval Time", None, None, self.context, "line"], # line indicates that it is a line graph
                'lines': [["seconds"]] #must be a valid key in 'get_data()'s return 
            }
        }
    @staticmethod
    def check():
        return True

    def get_data(self):
        data = {}
        start = time.time()
        api_data = call_monitor(self.endpoint)
        end = time.time()

        retrieval_time = end - start

        for dimension_id in api_data.keys():

            if dimension_id not in self.charts[self.chart_name]:
                self.charts[self.chart_name].add_dimension([dimension_id])

            data[dimension_id] = api_data[dimension_id]
        
        timer_chart = "data retrieval time"

        if "seconds" not in self.charts[timer_chart]:
            self.charts[timer_chart].add_dimension(["seconds"])

        data["seconds"] = retrieval_time
        return data
