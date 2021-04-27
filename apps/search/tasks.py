from newsblur_web.celeryapp import app
from utils import log as logging

@app.task()
def IndexSubscriptionsForSearch(user_id):
    from apps.search.models import MUserSearch
    
    user_search = MUserSearch.get_user(user_id)
    user_search.index_subscriptions_for_search()

@app.task()
def IndexSubscriptionsChunkForSearch(feed_ids, user_id):
    logging.debug(" ---> Indexing: %s for %s" % (feed_ids, user_id))
    from apps.search.models import MUserSearch
    
    user_search = MUserSearch.get_user(user_id)
    user_search.index_subscriptions_chunk_for_search(feed_ids)

@app.task()
def IndexFeedsForSearch(feed_ids, user_id):
    from apps.search.models import MUserSearch
    
    MUserSearch.index_feeds_for_search(feed_ids, user_id)

@app.task()
def FinishIndexSubscriptionsForSearch(results, user_id, start):
    logging.debug(" ---> Indexing finished for %s" % (user_id))
    from apps.search.models import MUserSearch

    user_search = MUserSearch.get_user(user_id)
    user_search.finish_index_subscriptions_for_search(start)
