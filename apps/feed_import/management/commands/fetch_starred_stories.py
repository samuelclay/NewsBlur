from django.core.management.base import BaseCommand
from django.conf import settings
from django.contrib.auth.models import User
from apps.feed_import.models import GoogleReaderImporter
from optparse import make_option
from utils.management_functions import daemonize


class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-d", "--daemon", dest="daemonize", action="store_true"),
        make_option('-u', '--username', type='str', dest='username'),
        make_option('-c', '--count', type='int', dest='count', default=1000),
        make_option('-V', '--verbose', action='store_true',
            dest='verbose', default=False, help='Verbose output.'),
    )

    def handle(self, *args, **options):
        if options['daemonize']:
            daemonize()
            
        settings.LOG_TO_STREAM = True
        
        try:
            user = User.objects.get(username__icontains=options['username'])
        except User.MultipleObjectsReturned:
            user = User.objects.get(username=options['username'])
        reader_importer = GoogleReaderImporter(user)
        reader_importer.import_starred_items(count=options['count'])
