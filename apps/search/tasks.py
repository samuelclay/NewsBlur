from celery.task import task

@task()
def IndexSubscriptionsForSearch(user_id):
    from apps.search.models import MUserSearch
    
    user_search = MUserSearch.get_user(user_id)
    user_search.index_subscriptions_for_search()

@task()
def IndexSubscriptionsChunkForSearch(feed_ids, user_id):
    from apps.search.models import MUserSearch
    
    user_search = MUserSearch.get_user(user_id)
    user_search.index_subscriptions_chunk_for_search(feed_ids)

@task()
def IndexFeedsForSearch(feed_ids, user_id):
    from apps.search.models import MUserSearch
    
    MUserSearch.index_feeds_for_search(feed_ids, user_id)
