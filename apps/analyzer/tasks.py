from celery.task import Task
from utils import log as logging

class EmailPopularityQuery(Task):
    
    def run(self, pk):
        from apps.analyzer.models import MPopularityQuery
        
        query = MPopularityQuery.objects.get(pk=pk)
        logging.debug(" -> ~BB~FCRunning popularity query: ~SB%s" % query)
        
        query.send_email()
        
