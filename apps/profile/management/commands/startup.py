#add homepage user from settings
#add popular user
import datetime
from django.conf import settings
from apps.profile.models import create_profile
from django.contrib.auth.models import User
from django.core.management.base import BaseCommand

class Command(BaseCommand):

    def handle(self, *args, **options):
        def _create(username):
            try:
                User.objects.get(username=username)
                print("User {0} exists".format(username))
            except User.DoesNotExist:
                instance = User.objects.create(username=username, last_login=datetime.datetime.now())
                instance.save()
                create_profile(None, instance, None)
                print("User {0} created".format(username))
        
        _create(settings.HOMEPAGE_USERNAME)
