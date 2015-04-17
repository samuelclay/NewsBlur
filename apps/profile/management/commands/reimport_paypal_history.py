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
        week = datetime.datetime.now() - datetime.timedelta(days=int(options.get('days')))
        failed = []
        limit = 100
        offset = options.get('offset')
        
        while True:
            logging.debug(" ---> At %s" % offset)
            user_ids = PaymentHistory.objects.filter(payment_provider='paypal', 
                          payment_date__gte=week).values('user_id').distinct()[offset:offset+limit]
            user_ids = [u['user_id'] for u in user_ids]
            if not len(user_ids):
                logging.debug("At %s, finished" % offset)
                break
            offset += limit
            for user_id in user_ids:
                try:
                    user = User.objectrs.get(pk=user_id)
                except User.DoesNotExist:
                    logging.debug(" ***> Couldn't find paypal user_id=%s" % user_id)
                    failed.append(user_id)

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

        return failed

