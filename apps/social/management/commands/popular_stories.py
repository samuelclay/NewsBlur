from django.core.management.base import BaseCommand

from apps.social.models import MSharedStory


class Command(BaseCommand):
    help = "Identify and share trending popular stories to the social feed."

    def handle(self, *args, **options):
        MSharedStory.share_popular_stories()
