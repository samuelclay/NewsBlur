import openai
import mongoengine as mongo
from itertools import groupby
from apps.rss_feeds.models import Feed
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from utils import json_functions as json
from utils.feed_functions import add_object_to_folder
from utils import log as logging

class MDiscoverFeed(mongo.Document):
    feed_id = mongo.IntField()
    related_feed_ids = mongo.ListField(mongo.IntField())
    
    meta = {
        'collection': 'discover_feeds',
        'indexes': ['feed_id', 'related_feed_ids'],
        'allow_inheritance': False,
    }
    
    def __str__(self):
        feed = Feed.get_by_id(self.feed_id)
        return "%s: related to %s sites" % (feed, len(self.related_feed_ids))

    @classmethod
    def fetch_related_feeds(feed_id,         openai_model="gpt-3.5-turbo-16k", max_tokens=16000,):
        feed = Feed.get_by_id(feed_id)
        if not feed or  not feed.feed_address:
            return []
        
