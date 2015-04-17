import stripe, datetime, time
from django.conf import settings

from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from optparse import make_option

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        # make_option("-u", "--username", dest="username", nargs=1, help="Specify user id or username"),
        # make_option("-e", "--email", dest="email", nargs=1, help="Specify email if it doesn't exist"),
        make_option("-d", "--days", dest="days", nargs=1, help="Number of days to go back"),
    )

    def handle(self, *args, **options):
        stripe.api_key = settings.STRIPE_SECRET
        week = (datetime.datetime.now() - datetime.timedelta(days=int(options.get('days', 365)))).strftime('%s')
        failed = []
        limit = 100
        offset = 0
        while True:
            print " ---> At %s" % offset
            try:
                data = stripe.Customer.all(created={'gt': week}, count=limit, offset=offset)
            except stripe.APIConnectionError:
                time.sleep(10)
                continue
            customers = data['data']
            if not len(customers):
                print "At %s, finished" % offset
                break
            offset += limit
            usernames = [c['description'] for c in customers]
            for username in usernames:
                try:
                    user = User.objects.get(username=username)
                except User.DoesNotExist:
                    print " ***> Couldn't find %s" % username
                    failed.append(username)
                try:
                    if not user.profile.is_premium:
                        user.profile.activate_premium()
                    elif user.payments.all().count() != 1:
                        user.profile.setup_premium_history()
                    elif not user.profile.premium_expire:
                        user.profile.setup_premium_history()
                    elif user.profile.premium_expire > datetime.datetime.now() + datetime.timedelta(days=365):
                        user.profile.setup_premium_history()
                    else:
                        print " ---> %s is fine" % username
                except stripe.APIConnectionError:
                    print " ***> Failed: %s" % username
                    failed.append(username)
                    time.sleep(2)
                    continue



