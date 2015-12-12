import mongoengine as mongo
from django.db import models
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from utils import json_functions as json
from collections import defaultdict

class RecommendedFeed(models.Model):
    feed          = models.ForeignKey(Feed, related_name='recommendations')
    user          = models.ForeignKey(User, related_name='recommendations')
    description   = models.TextField(null=True, blank=True)
    is_public     = models.BooleanField(default=False)
    created_date  = models.DateField(auto_now_add=True)
    approved_date = models.DateField(null=True)
    declined_date = models.DateField(null=True)
    twitter       = models.CharField(max_length=50, null=True, blank=True)
    
    def __unicode__(self):
        return "%s (%s)" % (self.feed, self.approved_date or self.created_date)
        
    class Meta:
        ordering = ['-approved_date', '-created_date']


class RecommendedFeedUserFeedback(models.Model):
    recommendation = models.ForeignKey(RecommendedFeed, related_name='feedback')
    user           = models.ForeignKey(User, related_name='feed_feedback')
    score          = models.IntegerField(default=0)
    created_date   = models.DateField(auto_now_add=True)

class MFeedFolder(mongo.Document):
    feed_id = mongo.IntField()
    folder = mongo.StringField()
    count = mongo.IntField()
    
    meta = {
        'collection': 'feed_folders',
        'indexes': ['feed_id', 'folder'],
        'allow_inheritance': False,
    }
    
    def __unicode__(self):
        feed = Feed.get_by_id(self.feed_id)
        return "%s - %s (%s)" % (feed, self.folder, self.count)
    
    @classmethod
    def count_feed(cls, feed_id):
        feed = Feed.get_by_id(feed_id)
        print feed
        found_folders = defaultdict(int)
        user_ids = [sub['user_id'] for sub in UserSubscription.objects.filter(feed=feed).values('user_id')]
        usf = UserSubscriptionFolders.objects.filter(user_id__in=user_ids)
        for sub in usf:
            user_sub_folders = json.decode(sub.folders)
            folder_title = cls.feed_folder_parent(user_sub_folders, feed.pk)
            if not folder_title: continue
            found_folders[folder_title.lower()] += 1
            # print "%-20s - %s" % (folder_title if folder_title != '' else '[Top]', sub.user_id)
        print sorted(found_folders.items(), key=lambda f: f[1], reverse=True)
        
        
    @classmethod
    def feed_folder_parent(cls, folders, feed_id, folder_title=''):
        for item in folders:
            if isinstance(item, int) and item == feed_id:
                return folder_title
            elif isinstance(item, dict):
                for f_k, f_v in item.items():
                    sub_folder_title = cls.feed_folder_parent(f_v, feed_id, f_k)
                    if sub_folder_title: 
                        return sub_folder_title
