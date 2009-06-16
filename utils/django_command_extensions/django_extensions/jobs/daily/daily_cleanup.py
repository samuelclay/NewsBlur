"""
Daily cleanup job.

Can be run as a cronjob to clean out old data from the database (only expired
sessions at the moment).
"""

from django_extensions.management.jobs import DailyJob

class Job(DailyJob):
    help = "Django Daily Cleanup Job"

    def execute(self):
	# TODO: Remove the old way when Django 1.0 lands
	try:
	    # old way of doing cleanup (pre r7844 in svn)
	    from django.bin.daily_cleanup import clean_up
	    clean_up()
	except:
	    # new way using the management.call_command function
	    from django.core import management
	    management.call_command("cleanup")
