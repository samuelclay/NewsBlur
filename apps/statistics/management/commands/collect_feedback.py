from django.core.management.base import BaseCommand

from apps.statistics.models import MFeedback


class Command(BaseCommand):
    help = "Aggregate user feedback submissions into the statistics store."

    def handle(self, *args, **options):
        MFeedback.collect_feedback()
