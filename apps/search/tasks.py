from celery.task import Task

class IndexSubscriptionsForSearch(Task):
    
    def run(self, user_id):
        from apps.search.models import MUserSearch
        
        user_search = MUserSearch.get_user(user_id)
        user_search.index_subscriptions_for_search()

class IndexSubscriptionsChunkForSearch(Task):
    
    ignore_result = False
    
    def run(self, feed_ids, user_id):
        from apps.search.models import MUserSearch
        
        user_search = MUserSearch.get_user(user_id)
        user_search.index_subscriptions_chunk_for_search(feed_ids)

class IndexFeedsForSearch(Task):
    
    def run(self, feed_ids, user_id):
        from apps.search.models import MUserSearch
        
        MUserSearch.index_feeds_for_search(feed_ids, user_id)