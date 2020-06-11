#add homepage user from settings
#add popular user
from settings import HOMEPAGE_USERNAME
from apps.profile.models import create_profile
from django.contrib.auth.models import User
from django.core.management.base import BaseCommand

class Command(BaseCommand):

    def handle(self, *args, **options):
        instance = User.objects.create(username=HOMEPAGE_USERNAME)
        instance.save()
        create_profile(None, instance, None)
        print("User {0} created".format(HOMEPAGE_USERNAME))