from celery.task import task
from utils import log as logging

@task()
def EmailPopularityQuery(pk):
    from apps.analyzer.models import MPopularityQuery
    
    query = MPopularityQuery.objects.get(pk=pk)
    logging.debug(" -> ~BB~FCRunning popularity query: ~SB%s" % query)
    
    query.send_email()
    
