import datetime
import enum
import pymongo
import redis
import mongoengine as mongo
from django.conf import settings
from django.contrib.auth.models import User
from django.template.loader import render_to_string
from django.core.mail import EmailMultiAlternatives
from apps.rss_feeds.models import MStory, Feed
from apps.reader.models import UserSubscription
from apps.analyzer.models import MClassifierTitle, MClassifierAuthor, MClassifierFeed, MClassifierTag
from apps.analyzer.models import compute_story_score
from utils import log as logging
from utils import mongoengine_fields
from HTMLParser import HTMLParser


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
    is_focus                 = mongo.BooleanField()
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
    def feed_has_users(cls, feed_id):
        return cls.users_for_feed(feed_id).count()
    
    @classmethod
    def users_for_feed(cls, feed_id):
        notifications = cls.objects.filter(feed_id=feed_id)
    
        return notifications
    
    @classmethod
    def feeds_for_user(cls, user_id):
        notifications = cls.objects.filter(user_id=user_id)
        notifications_by_feed = {}

        for feed in notifications:
            notifications_by_feed[feed.feed_id] = {
                'notification_types': [],
                'notification_filter': "focus" if feed.is_focus else "unread",
            }
            if feed.is_email: notifications_by_feed[feed.feed_id]['notification_types'].append('email')
            if feed.is_web: notifications_by_feed[feed.feed_id]['notification_types'].append('web')
            if feed.is_ios: notifications_by_feed[feed.feed_id]['notification_types'].append('ios')
            if feed.is_android: notifications_by_feed[feed.feed_id]['notification_types'].append('android')
            
        return notifications_by_feed
    
    @classmethod
    def push_feed_notifications(cls, feed_id, new_stories, force=False):
        feed = Feed.get_by_id(feed_id)
        notifications = MUserFeedNotification.users_for_feed(feed.pk)
        logging.debug("   ---> [%-30s] ~FCPushing out notifications to ~SB%s users~SN for ~FB~SB%s stories" % (
                      feed, len(notifications), new_stories))
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        
        latest_story_hashes = r.zrange("zF:%s" % feed.pk, -1 * new_stories, -1)
        mstories = MStory.objects.filter(story_hash__in=latest_story_hashes).order_by('-story_date')
        stories = Feed.format_stories(mstories)
        
        for user_feed_notification in notifications:
            sent_count = 0
            last_notification_date = user_feed_notification.last_notification_date
            try:
                usersub = UserSubscription.objects.get(user=user_feed_notification.user_id,
                                                       feed=user_feed_notification.feed_id)
            except UserSubscription.DoesNotExist:
                continue
            classifiers = user_feed_notification.classifiers(usersub)

            if classifiers == None:
                logging.debug("Has no usersubs")
                continue

            for story in stories:
                if sent_count >= 3:
                    logging.debug("Sent too many, ignoring...")
                    continue                    
                if story['story_date'] < last_notification_date and not force:
                    logging.debug("Story date older than last notification date: %s < %s" % (story['story_date'], last_notification_date))
                    continue
                
                if story['story_date'] > user_feed_notification.last_notification_date:
                    user_feed_notification.last_notification_date = story['story_date']
                    user_feed_notification.save()
                
                sent = user_feed_notification.push_story_notification(story, classifiers, usersub)
                if sent: sent_count += 1
    
    def classifiers(self, usersub):
        classifiers = {}
        if usersub.is_trained:
            user = User.objects.get(pk=self.user_id)
            classifiers['feeds']   = list(MClassifierFeed.objects(user_id=self.user_id, feed_id=self.feed_id,
                                                                 social_user_id=0))
            classifiers['authors'] = list(MClassifierAuthor.objects(user_id=self.user_id, feed_id=self.feed_id))
            classifiers['titles']  = list(MClassifierTitle.objects(user_id=self.user_id, feed_id=self.feed_id))
            classifiers['tags']    = list(MClassifierTag.objects(user_id=self.user_id, feed_id=self.feed_id))
            
        return classifiers
        
    def push_story_notification(self, story, classifiers, usersub):
        story_score = self.story_score(story, classifiers)
        if self.is_focus and story_score <= 0:
            logging.debug("Is focus, but story is hidden")
            return False
        elif story_score < 0:
            logging.debug("Is unread, but story is hidden")
            return False
        
        user = User.objects.get(pk=self.user_id)
        logging.user(user, "~FCSending push notification: %s/%s (score: %s)" % (story['story_title'][:40], story['story_hash'], story_score))
        
        self.send_web(story)
        self.send_ios(story)
        self.send_android(story)
        self.send_email(story, usersub)
        
        return True
    
    def send_web(self, story):
        if not self.is_web: return
        
        user = User.objects.get(pk=self.user_id)
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        r.publish(user.username, 'notification:%s,%s' % (story['story_hash'], story['story_title']))
    
    def send_ios(self, story):
        if not self.is_ios: return
        
        
    def send_android(self, story):
        if not self.is_android: return
        
        
    def send_email(self, story, usersub):
        if not self.is_email: return
        feed = usersub.feed
        
        story['story_content'] = HTMLParser().unescape(story['story_content'])
        params  = {
            "story": story,
            "feed": feed,
            "feed_title": usersub.user_title or feed.feed_title,
            "favicon_border": feed.favicon_border(),
        }
        from_address = 'share@newsblur.com'
        to_address = '%s <%s>' % (usersub.user.username, usersub.user.email)
        text    = render_to_string('mail/email_story_notification.txt', params)
        html    = render_to_string('mail/email_story_notification.xhtml', params)
        subject = '%s: %s' % (usersub.user_title or usersub.feed.feed_title, story['story_title'])
        subject = subject.replace('\n', ' ')
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % from_address,
                                         to=[to_address])
        msg.attach_alternative(html, "text/html")
        try:
            msg.send()
        except boto.ses.connection.ResponseError, e:
            code = -1
            message = "Email error: %s" % str(e)
        logging.user(usersub.user, '~BMStory notification by email: ~FY~SB%s~SN~BM~FY/~SB%s' % 
                                   (story['story_title'][:50], usersub.feed.feed_title[:50]))
        
    def story_score(self, story, classifiers):
        score = compute_story_score(story, classifier_titles=classifiers.get('titles', []), 
                                    classifier_authors=classifiers.get('authors', []), 
                                    classifier_tags=classifiers.get('tags', []),
                                    classifier_feeds=classifiers.get('feeds', []))
        
        return score
                
