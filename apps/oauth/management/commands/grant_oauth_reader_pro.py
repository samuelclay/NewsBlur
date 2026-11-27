from django.apps import apps
from django.core.management.base import BaseCommand
from django.db import DEFAULT_DB_ALIAS

from apps.oauth.reader_grants import grant_reader_accounts


class Command(BaseCommand):
    help = "Preview or apply lifetime Premium Pro grants for the approved Goodies reader accounts."

    def add_arguments(self, parser):
        parser.add_argument("--apply", action="store_true", help="Apply the grants shown in the preview.")

    def handle(self, *args, **options):
        grant_reader_accounts(apps, DEFAULT_DB_ALIAS, apply=options["apply"], report=self.stdout.write)
