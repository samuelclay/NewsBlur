import stripe, datetime, time
from django.conf import settings

from django.core.management.base import BaseCommand
from django.contrib.auth.models import User

from utils import log as logging
from apps.profile.models import Profile, PaymentHistory

class Command(BaseCommand):

    def add_arguments(self, parser):
        parser.add_argument("-d", "--days", dest="days", nargs=1, type=int, default=365, help="Number of days to go back")
        parser.add_argument("-o", "--offset", dest="offset", nargs=1, type=int, default=0, help="Offset customer (in date DESC)")
        parser.add_argument("-f", "--force", dest="force", nargs=1, type=bool, default=False, help="Force reimport for every user")
    
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
                    user = User.objects.get(pk=user_id)
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
                elif options.get('force'):
                    user.profile.setup_premium_history()
                else:
                    logging.debug(" ---> %s is fine" % user.username)

        return failed

