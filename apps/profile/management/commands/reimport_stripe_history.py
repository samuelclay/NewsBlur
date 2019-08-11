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
        limit = options.get('limit')
        days = int(options.get('days'))
        starting_after = options.get('start')
        
        Profile.reimport_stripe_history(limit, days, starting_after)