import datetime
from celery.task import Task
from utils import log as logging

class EmailPopularityQuery(Task):
    
    def run(self, pk):
        from apps.analyzer.models import MPopularityQuery
        
        query = MPopularityQuery.objects.get(pk=pk)
        logging.user(self.user, "~BB~FCRunning popularity query: ~SB%s" % query)
        
        query.send_email()
        query.is_emailed = True
        query.save()
        
