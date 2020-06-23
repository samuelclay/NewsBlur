#add homepage user from settings
#add popular user
from settings import HOMEPAGE_USERNAME
from apps.profile.models import create_profile
from django.contrib.auth.models import User
from django.core.management.base import BaseCommand

class Command(BaseCommand):

    def handle(self, *args, **options):
        try:
            user = User.objects.get(username=HOMEPAGE_USERNAME)
            print(f"Found user {HOMEPAGE_USERNAME}")
        except:
            user = User.objects.create(username=HOMEPAGE_USERNAME)
            user.save()
            print(f"Created user {HOMEPAGE_USERNAME}")

        try:
            create_profile(None, user, None)
        except:
            print(f"Profile already created for user {user.username}")
        print("User {0} created".format(HOMEPAGE_USERNAME))
