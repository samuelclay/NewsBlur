from django.core.management.base import BaseCommand
from apps.social.models import MSharedStory

class Command(BaseCommand):

    def handle(self, *args, **options):
        MSharedStory.share_popular_stories()