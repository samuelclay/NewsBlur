from django.core.management.base import BaseCommand
from apps.rss_feeds.tasks import BackupMongo

class Command(BaseCommand):
    option_list = BaseCommand.option_list

    def handle(self, *args, **options):
        BackupMongo.apply()