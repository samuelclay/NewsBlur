from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from apps.categories.models import MCategory
from optparse import make_option
import datetime

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-t", "--title", dest="title", nargs=1, help="Specify title of a feed category"),
        make_option("-d", "--description", dest="description", nargs=1, help="Specify description of a feed category"),
    )

    def handle(self, *args, **options):
        title  = options.get('title')
        description  = options.get('description')

        if title and description:
            category_db = {
                "title": title,
                "description": description
            }
            MCategory.objects.create(**category_db)

            print " ---> All notification sent!"
