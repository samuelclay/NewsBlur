from celery.task import Task
from django.contrib.auth.models import User
from apps.notifications.models import MUserFeedNotification
from utils import log as logging


class QueueNotifications(Task):
    
    def run(self, feed_id, new_stories):
        MUserFeedNotification.push_feed_notifications(feed_id, new_stories)