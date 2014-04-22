from celery.task import Task

class IndexSubscriptionsForSearch(Task):
    
    def run(self, user_id):
        from apps.search.models import MUserSearch
        
        user_search = MUserSearch.get_user(user_id)
        user_search.index_subscriptions_for_search()
