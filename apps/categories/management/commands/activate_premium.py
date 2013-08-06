from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from optparse import make_option
import datetime

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-u", "--username", dest="username", nargs=1, help="Specify user id or username"),
        make_option("-e", "--expire", dest="expire", nargs=1, help="Premium expire year", default=1, type='int'),
    )

    def handle(self, *args, **options):
        username = options.get('username')
        expire = options.get('expire')
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
            user.profile.activate_premium()
            if expire:
                user.profile.premium_expire = datetime.datetime.now() + datetime.timedelta(days=365 * expire)
            else:
                user.profile.premium_expire = datetime.datetime.now() + datetime.timedelta(days=365)
            user.profile.save()
        else:
            print " ---> No user found at: %s" % (username)
            
        
