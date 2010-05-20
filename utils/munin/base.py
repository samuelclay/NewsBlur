import sys

class MuninGraph(object):
    def __init__(self, graph_config, metrics):
        self.graph_config = graph_config
        self.metrics = metrics

    def run(self):
        cmd_name = None
        if len(sys.argv) > 1:
            cmd_name = sys.argv[1]
        if cmd_name == 'config':
            self.print_config()
        else: 
            self.print_metrics()

    def print_config(self):
        for key,value in self.graph_config.items():
            print '%s %s' % (key, value)

    def print_metrics(self):
        for key, value in self.metrics.items():
            print '%s.value %s' % (key, value)
