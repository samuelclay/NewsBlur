from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from apps.categories.models import MCategorySite, MCategory
from optparse import make_option
import datetime

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", dest="feed", nargs=1, help="Feed id", type='int'),
        make_option("-t", "--title", dest="title", nargs=1, help="Specify title of a feed category"),
    )

    def handle(self, *args, **options):
        feed_id = options.get('feed')
        category_title  = options.get('title')

        if feed_id and category_title:
            category_site_db = {
                "feed_id": feed_id,
                "category_title": category_title
            }
            MCategorySite.objects.create(**category_site_db)
            MCategory.reload_sites(category_title)

            print " ---> All notification sent!"
