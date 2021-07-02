from newsblur_web.celeryapp import app
from django.contrib.auth.models import User
from apps.notifications.models import MUserFeedNotification
from utils import log as logging


@app.task()
def QueueNotifications(feed_id, new_stories):
    MUserFeedNotification.push_feed_notifications(feed_id, new_stories)
