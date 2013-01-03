from optparse import make_option
from django.core.management.base import BaseCommand
from apps.statistics.models import MStatistics

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
    )

    def handle(self, *args, **options):
        MStatistics.collect_statistics()
        