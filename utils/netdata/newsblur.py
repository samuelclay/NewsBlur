import os
os.environ["DJANGO_SETTINGS_MODULE"] = "newsblur_web.settings"

from bases.FrameworkServices.SimpleService import SimpleService

priority = 90000

ORDER = [
    'NewsBlur App Server Page Loads - by day',
    'NewsBlur App Server Page Loads - by week',
    'NewsBlur App Server Times - by day',
    'NewsBlur App Server Times - by week',
    'NewsBlur Classifiers - by day',
    'NewsBlur Classifiers - by week',
    'NewsBlur DB Times - by day',
    'NewsBlur DB Times - by week',
    'NewsBlur Feed Counts - by day',
    'NewsBlur Feed Counts - by week',
    'NewsBlur Feeds & Subscriptions - by day',
    'NewsBlur Feeds & Subscriptions - by week',
    'NewsBlur Fetching History - by day',
    'NewsBlur Fetching History - by week'
    'NewsBlur Load Times - by day',
    'NewsBlur Load Times - by week',
    'NewsBlur Stories - by day',
    'NewsBlur Stories - by week',
    'NewsBlur Task Codes - by day',
    'NewsBlur Task Codes - by week',
    'NewsBlur Task Pipeline - by day',
    'NewsBlur Task Pipeline - by week',
    'NewsBlur Task Server Fetches - by day',
    'NewsBlur Task Server Fetches - by week',
    'NewsBlur Task Server Times - by day',
    'NewsBlur Task Server Times - by week',
    'NewsBlur Updates - by day',
    'NewsBlur Updates - by week',
    'NewsBlur Users - by day',
    'NewsBlur Users - by week'
]

CHARTS = {
    'NewsBlur Updates': {
        #'options': [name, title, units, family, context, charttype],
        'options': [
            'NewsBlur App Server Page Loads - by day',
            'NewsBlur App Server Page Loads - by day',
            '# of page loads / server',
            'App Server',
            None,
            'stacked'
        ]
        'lines': [
            [
                'Queued Feeds',
                'Fetched feeds last hour',
                'Tasked Feeds',
                'Error Feeds',
                'Celery - Update Feeds',
                'Celery - New Feeds',
                'Celery - Push Feeds',
                'Celery - Work Queue',
                'Celery - Search Queue',
            ]
        ]
    }
}


class Service(SimpleService):
    def __init__(self, configuration=None, name=None):
        SimpleService.__init__(self, configuration=configuration, name=name)
        self.order = ORDER
        self.definitions = CHARTS
        self.random = SystemRandom()
        self.num_lines = self.configuration.get('num_lines', 4)
        self.lower = self.configuration.get('lower', 0)
        self.upper = self.configuration.get('upper', 100)

    @staticmethod
    def check():
        return True

    def get_data(self):
        data = dict()

        for i in range(0, self.num_lines):
            dimension_id = ''.join(['random', str(i)])

            if dimension_id not in self.charts['random']:
                self.charts['random'].add_dimension([dimension_id])

            data[dimension_id] = self.random.randint(self.lower, self.upper)

        return data