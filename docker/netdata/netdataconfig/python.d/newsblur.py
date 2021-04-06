from random import SystemRandom
from bases.FrameworkServices.SimpleService import SimpleService

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
        self.num_lines = 1
        self.lower = self.configuration.get('lower', 0)
        self.upper = self.configuration.get('upper', 100)

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

            data[dimension_id] = self.random.randint(self.lower, self.upper)
        return data