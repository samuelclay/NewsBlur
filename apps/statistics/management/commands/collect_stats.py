from django.core.management.base import BaseCommand

from apps.statistics.models import MStatistics


class Command(BaseCommand):
    help = "Collect system-wide statistics (user counts, feed activity, performance metrics)."

    def handle(self, *args, **options):
        MStatistics.collect_statistics()
