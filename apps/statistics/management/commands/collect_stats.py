from django.core.management.base import BaseCommand
from apps.statistics.models import MStatistics

class Command(BaseCommand):

    def handle(self, *args, **options):
        MStatistics.collect_statistics()
        