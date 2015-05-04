import stripe, datetime, time
from django.conf import settings

from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from optparse import make_option

from utils import log as logging
from apps.profile.models import Profile, PaymentHistory

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        # make_option("-u", "--username", dest="username", nargs=1, help="Specify user id or username"),
        # make_option("-e", "--email", dest="email", nargs=1, help="Specify email if it doesn't exist"),
        make_option("-d", "--days", dest="days", nargs=1, type='int', default=365, help="Number of days to go back"),
        make_option("-o", "--offset", dest="offset", nargs=1, type='int', default=0, help="Offset customer (in date DESC)"),
    )

    def handle(self, *args, **options):
        stripe.api_key = settings.STRIPE_SECRET
        week = (datetime.datetime.now() - datetime.timedelta(days=int(options.get('days', 365)))).strftime('%s')
        failed = []
        limit = 100
        offset = options.get('offset')
        
        while True:
            logging.debug(" ---> At %s" % offset)
            try:
                data = stripe.Charge.all(created={'gt': week}, count=limit, offset=offset)
            except stripe.APIConnectionError:
                time.sleep(10)
                continue
            charges = data['data']
            if not len(charges):
                logging.debug("At %s, finished" % offset)
                break
            offset += limit
            customers = [c['customer'] for c in charges if 'customer' in c]
            for customer in customers:
                try:
                    profile = Profile.objects.get(stripe_id=customer)
                    user = profile.user
                except Profile.DoesNotExist:
                    logging.debug(" ***> Couldn't find stripe_id=%s" % customer)
                    failed.append(customer)
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
                        logging.debug(" ---> %s is fine" % user.username)
                except stripe.APIConnectionError:
                    logging.debug(" ***> Failed: %s" % user.username)
                    failed.append(username)
                    time.sleep(2)
                    continue

        return failed

