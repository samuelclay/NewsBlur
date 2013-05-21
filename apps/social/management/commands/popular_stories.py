from django.core.management.base import BaseCommand
from apps.social.models import MSharedStory
from optparse import make_option

class Command(BaseCommand):
    option_list = BaseCommand.option_list

    def handle(self, *args, **options):
        MSharedStory.share_popular_stories()