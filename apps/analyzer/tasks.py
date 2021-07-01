from newsblur_web.celeryapp import app
from utils import log as logging

@app.task()
def EmailPopularityQuery(pk):
    from apps.analyzer.models import MPopularityQuery
    
    query = MPopularityQuery.objects.get(pk=pk)
    logging.debug(" -> ~BB~FCRunning popularity query: ~SB%s" % query)
    
    query.send_email()
    
