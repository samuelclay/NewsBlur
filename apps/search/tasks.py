from celery.task import Task
from django.contrib.auth.models import User


class IndexSubscriptionsForSearch(Task):
    
    def run(self, user_id):
        user = User.objects.get(pk=user_id)
        user.profile.index_subscriptions_for_search()
