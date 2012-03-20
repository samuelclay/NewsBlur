from django.core.management.base import BaseCommand
from apps.social.models import MSharedStory
from optparse import make_option

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-V", "--verbose", dest="verbose", action="store_true"),
    )

    def handle(self, *args, **options):
        MSharedStory.count_popular_stories(verbose=options['verbose'])