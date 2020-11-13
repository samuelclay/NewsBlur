from celery.task import task
from django.contrib.auth.models import User
from apps.notifications.models import MUserFeedNotification
from utils import log as logging


@task()
def QueueNotifications(feed_id, new_stories):
    MUserFeedNotification.push_feed_notifications(feed_id, new_stories)
