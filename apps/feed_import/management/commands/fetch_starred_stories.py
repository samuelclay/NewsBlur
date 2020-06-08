from django.core.management.base import BaseCommand
from django.conf import settings
from django.contrib.auth.models import User
from apps.feed_import.models import GoogleReaderImporter
from utils.management_functions import daemonize


class Command(BaseCommand):
    def add_arguments(self, parser):
        parser.add_argument(
            '--daemon',
            '-d',
            dest='daemonize',
            action="store_true"
        )
        parser.add_argument(
            '--username',
            '-u'
            type=str,
            dest='username'
        )
        parser.add_argument(
            '--count',
            '-c'
            type=int,
            dest='count',
            default=1000
        )
        parser.add_argument(
            '--verbose',
            '-V',
            action='store_true',
            dest='verbose',
            default=False,
            help='Verbose output.'
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
