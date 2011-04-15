import datetime
import mongoengine as mongo
from apps.rss_feeds.models import MFeedFetchHistory
from apps.profile.models import Profile

class MStatistics(mongo.Document):
    key   = mongo.StringField(unique=True)
    value = mongo.IntField(default=0)
    
    meta = {
        'collection': 'statistics',
        'allow_inheritance': False,
        'indexes': ['key'],
    }
    
    def __unicode__(self):
        return "%s: %s" % (self.key, self.value)
    
    @classmethod
    def all(cls):
        return dict([(stat.key, stat.value) for stat in cls.objects.all()])
        
    @classmethod
    def collect_statistics(cls):
        last_day = datetime.datetime.now() - datetime.timedelta(hours=24)
        feeds_fetched = MFeedFetchHistory.objects(fetch_date__gte=last_day).count()
        cls.objects(key='feeds_fetched').update_one(upsert=True, key='feeds_fetched', value=feeds_fetched)
        
        premium_users = Profile.objects.filter(last_seen_on__gte=last_day, is_premium=True).count()
        cls.objects(key='premium_users').update_one(upsert=True, key='premium_users', value=premium_users)
        
        standard_users = Profile.objects.filter(last_seen_on__gte=last_day, is_premium=False).count()
        cls.objects(key='standard_users').update_one(upsert=True, key='standard_users', value=standard_users)