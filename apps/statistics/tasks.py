from celery.task import Task
from apps.statistics.models import MStatistics
from apps.statistics.models import MFeedback
# from utils import log as logging



class CollectStats(Task):
    name = 'collect-stats'

    def run(self, **kwargs):
        # logging.debug(" ---> ~FBCollecting stats...")
        MStatistics.collect_statistics()
        
        
class CollectFeedback(Task):
    name = 'collect-feedback'

    def run(self, **kwargs):
        # logging.debug(" ---> ~FBCollecting feedback...")
        MFeedback.collect_feedback()