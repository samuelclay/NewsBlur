from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from optparse import make_option
import datetime

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-u", "--username", dest="username", nargs=1, help="Specify user id or username"),
    )

    def handle(self, *args, **options):
        username = options.get('username')
        user = None
        if username:
            try:
                user = User.objects.get(username__icontains=username)
            except User.MultipleObjectsReturned:
                user = User.objects.get(username__iexact=username)
            except User.DoesNotExist:
                user = User.objects.get(email__iexact=username)
            except User.DoesNotExist:
                print " ---> No user found at: %s" % username
            
        if user:
            user.profile.send_notification_email()
        else:
           # users = User.objects.all()
            for user in users:
                user.profile.send_notification_email()
                print " ---> Mail sent to %s." % user.id
            print " ---> All notification sent!"
