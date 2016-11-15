import datetime
import enum
import pymongo
import redis
import mongoengine as mongo
from django.conf import settings
from django.contrib.auth.models import User
from utils import log as logging
from utils import mongoengine_fields


class NotificationFrequency(enum.Enum):
    immediately = 1
    hour_1 = 2
    hour_6 = 3
    hour_12 = 4
    hour_24 = 5


class MUserFeedNotification(mongo.Document):
    '''A user's notifications of a single feed.'''
    user_id                  = mongo.IntField()
    feed_id                  = mongo.IntField()
    frequency                = mongoengine_fields.IntEnumField(NotificationFrequency)
    last_notification_date   = mongo.DateTimeField(default=datetime.datetime.now)
    is_email                 = mongo.BooleanField()
    is_web                   = mongo.BooleanField()
    is_ios                   = mongo.BooleanField()
    is_android               = mongo.BooleanField()
    
    meta = {
        'collection': 'notifications',
        'indexes': ['feed_id',
                    {'fields': ['user_id', 'feed_id'], 
                     'unique': True,
                     'types': False, }],
        'allow_inheritance': False,
    }
    
    def __unicode__(self):
        notification_types = []
        if self.is_email: notification_types.append('email')
        if self.is_web: notification_types.append('web')
        if self.is_ios: notification_types.append('ios')
        if self.is_android: notification_types.append('android')

        return "%s/%s: %s -> %s" % (
            User.objects.get(pk=self.user_id).username,
            Feed.get_feed_by_id(self.feed_id),
            ','.join(notification_types),
            self.last_notification_date,
        )
    
    @classmethod
    def feeds_for_user(cls, user_id):
        notifications = cls.objects.filter(user_id=user_id)
        notifications_by_feed = {}

        for feed in notifications:
            notifications_by_feed[feed.feed_id] = {
                'notifications': [],
                'notification_freq': feed.frequency
            }
            if feed.is_email: notifications_by_feed[feed.feed_id]['notifications'].append('email')
            if feed.is_web: notifications_by_feed[feed.feed_id]['notifications'].append('web')
            if feed.is_ios: notifications_by_feed[feed.feed_id]['notifications'].append('ios')
            if feed.is_android: notifications_by_feed[feed.feed_id]['notifications'].append('android')
            
        return notifications_by_feed