import sys

class MuninGraph(object):

    def run(self):
        cmd_name = None
        if len(sys.argv) > 1:
            cmd_name = sys.argv[1]
        if cmd_name == 'config':
            self.print_config()
        else: 
            metrics = self.calculate_metrics()
            self.print_metrics(metrics)
            
    def print_config(self):
        for key,value in self.graph_config.items():
            print '%s %s' % (key, value)

    def print_metrics(self, metrics):
        for key, value in metrics.items():
            print '%s.value %s' % (key, value)
            