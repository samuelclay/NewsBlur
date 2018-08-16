import stripe, datetime, time
from django.conf import settings

from django.core.management.base import BaseCommand
from optparse import make_option

from utils import log as logging
from apps.profile.models import Profile

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        # make_option("-u", "--username", dest="username", nargs=1, help="Specify user id or username"),
        # make_option("-e", "--email", dest="email", nargs=1, help="Specify email if it doesn't exist"),
        make_option("-d", "--days", dest="days", nargs=1, type='int', default=365, help="Number of days to go back"),
        make_option("-l", "--limit", dest="limit", nargs=1, type='int', default=100, help="Charges per batch"),
        make_option("-s", "--start", dest="start", nargs=1, type='string', default=None, help="Offset customer_id (starting_after)"),
    )

    def handle(self, *args, **options):
        stripe.api_key = settings.STRIPE_SECRET
        week = (datetime.datetime.now() - datetime.timedelta(days=int(options.get('days', 365)))).strftime('%s')
        failed = []
        limit = options.get('limit')
        starting_after = options.get('start')
        i = 0
        
        while True:
            logging.debug(" ---> At %s / %s" % (i, starting_after))
            i += 1
            try:
                data = stripe.Charge.all(created={'gt': week}, count=limit, starting_after=starting_after)
            except stripe.APIConnectionError:
                time.sleep(10)
                continue
            charges = data['data']
            if not len(charges):
                logging.debug("At %s (%s), finished" % (i, starting_after))
                break
            starting_after = charges[-1]["id"]
            customers = [c['customer'] for c in charges if 'customer' in c]
            for customer in customers:
                if not customer:
                    print " ***> No customer!"
                    continue
                try:
                    profile = Profile.objects.get(stripe_id=customer)
                    user = profile.user
                except Profile.DoesNotExist:
                    logging.debug(" ***> Couldn't find stripe_id=%s" % customer)
                    failed.append(customer)
                try:
                    user.profile.setup_premium_history()
                except stripe.APIConnectionError:
                    logging.debug(" ***> Failed: %s" % user.username)
                    failed.append(user.username)
                    time.sleep(2)
                    continue

        return ','.join(failed)

