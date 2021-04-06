# -*- coding: utf-8 -*-
# Description: example netdata python.d module
# Author: Put your name here (your github login)
# SPDX-License-Identifier: GPL-3.0-or-later

from random import SystemRandom

from bases.FrameworkServices.SimpleService import SimpleService

priority = 90000

ORDER = [
    'app-servers',
    'feed-counts'
]

CHARTS = {
    'app-servers': {
        # 'options': [name, title, units, family, context, charttype]
        'options': [None, 'App Servers', 'Total', 'family', 'context', 'stacked'], # line indicates that it is a line graph
        'lines': [
            ['app servers total'] #must be a valid key in 'get_data()'s return 
        ]
    },
    'feed-counts': {
        # 'options': [name, title, units, family, context, charttype]
        'options': [None, 'Feed Counts', 'Total', 'family', 'context', 'line'], # line indicates that it is a line graph
        'lines': [
            ['feed counts total'] #must be a valid key in 'get_data()'s return 
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
            "feed-counts": "feed counts total"
        }
        for chart, dimension_id in charts.items():

            if dimension_id not in self.charts[chart]:
                self.charts[chart].add_dimension([dimension_id])

            data[dimension_id] = self.random.randint(self.lower, self.upper)
        return data