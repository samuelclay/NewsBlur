from celery.task import Task
from apps.profile.models import Profile


class EmailNewUser(Task):
    
    def run(self, user_id):
        user_profile = Profile.objects.get(user__pk=user_id)
        user_profile.send_new_user_email()

class EmailNewPremium(Task):
    
    def run(self, user_id):
        user_profile = Profile.objects.get(user__pk=user_id)
        user_profile.send_new_premium_email()
