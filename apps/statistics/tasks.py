from newsblur_web.celeryapp import app
from apps.statistics.models import MStatistics
from apps.statistics.models import MFeedback
from utils import log as logging



@app.task(name='collect-stats')
def CollectStats():
    logging.debug(" ---> ~FBCollecting stats...")
    MStatistics.collect_statistics()
        
        
@app.task(name='collect-feedback')
def CollectFeedback():
    logging.debug(" ---> ~FBCollecting feedback...")
    MFeedback.collect_feedback()
