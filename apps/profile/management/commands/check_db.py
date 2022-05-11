import time
from django.core.management.base import BaseCommand
from django.db import connections
from django.db.utils import OperationalError

class Command(BaseCommand):

    def handle(self, *args, **options):
        db_conn = connections['default']
        connected = False
        while not connected:
            try:
                c = db_conn.cursor()
                connected = True
                # print("Connected to postgres")
            except OperationalError as e:
                print(f" ---> Waiting for db_postgres: {e}")
                time.sleep(5)
