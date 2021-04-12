from bases.FrameworkServices.SimpleService import SimpleService
import os
import requests
        
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
        return res.json()
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
            self.configuration.get("chart_name")
        ]
        self.definitions = {
            self.chart_name: {
                # 'options': [name, title, units, family, context, charttype]
                'options': [None, self.title, None, None, self.context, 'stacked'], # line indicates that it is a line graph
                'lines': [[key] for key in call_monitor(self.endpoint)] #must be a valid key in 'get_data()'s return 
                
            }
        }

    @staticmethod
    def check():
        return True

    def get_data(self):
        data = {}
        api_data = call_monitor(self.endpoint)

        for key in call_monitor(self.endpoint).keys():
            dimension_id = key

            if dimension_id not in self.charts[self.chart_name]:
                self.charts[self.chart_name].add_dimension([dimension_id])

            data[dimension_id] = api_data[dimension_id]

        return data
