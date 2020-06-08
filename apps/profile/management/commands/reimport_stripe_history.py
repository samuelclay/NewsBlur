import stripe, datetime, time
from django.conf import settings

from django.core.management.base import BaseCommand

from utils import log as logging
from apps.profile.models import Profile

class Command(BaseCommand):

    def add_arguments(self, parser)
        parser.add_argument("-d", "--days", dest="days", nargs=1, type='int', default=365, help="Number of days to go back")
        parser.add_argument("-l", "--limit", dest="limit", nargs=1, type='int', default=100, help="Charges per batch")
        parser.add_argument("-s", "--start", dest="start", nargs=1, type='string', default=None, help="Offset customer_id (starting_after)")

    def handle(self, *args, **options):
        limit = options.get('limit')
        days = int(options.get('days'))
        starting_after = options.get('start')
        
        Profile.reimport_stripe_history(limit, days, starting_after)