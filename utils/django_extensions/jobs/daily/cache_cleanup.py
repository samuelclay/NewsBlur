"""
Daily cleanup job.

Can be run as a cronjob to clean out old data from the database (only expired
sessions at the moment).
"""

from django_extensions.management.jobs import DailyJob

class Job(DailyJob):
    help = "Cache (db) cleanup Job"

    def execute(self):
        from django.conf import settings
        import os

        if settings.CACHE_BACKEND.startswith('db://'):
            os.environ['TZ'] = settings.TIME_ZONE
            table_name = settings.CACHE_BACKEND[5:]
            cursor = connection.cursor()
            cursor.execute("DELETE FROM %s WHERE %s < UTC_TIMESTAMP()" % \
                (backend.quote_name(table_name), backend.quote_name('expires')))
            transaction.commit_unless_managed()
