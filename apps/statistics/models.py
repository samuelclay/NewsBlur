import datetime
import mongoengine as mongo
from django.db.models import Avg, Count
from apps.rss_feeds.models import MFeedFetchHistory, FeedLoadtime
from apps.profile.models import Profile
from utils import json_functions as json
class MStatistics(mongo.Document):
    key   = mongo.StringField(unique=True)
    value = mongo.StringField()
    
    meta = {
        'collection': 'statistics',
        'allow_inheritance': False,
        'indexes': ['key'],
    }
    
    def __unicode__(self):
        return "%s: %s" % (self.key, self.value)
    
    @classmethod
    def all(cls):
        values = dict([(stat.key, stat.value) for stat in cls.objects.all()])
        for key, value in values.items():
            if key in ('avg_time_taken', 'sites_loaded'):
                values[key] = json.decode(value)
            elif key in ('feeds_fetched', 'premium_users', 'standard_users', 'latest_sites_loaded',
                         'max_sites_loaded'):
                values[key] = int(value)
            elif key in ('latest_avg_time_taken', 'max_avg_time_taken'):
                values[key] = float(value)
                
        return values
        
    @classmethod
    def collect_statistics(cls):
        last_day = datetime.datetime.now() - datetime.timedelta(hours=24)
        feeds_fetched = MFeedFetchHistory.objects(fetch_date__gte=last_day).count()
        cls.objects(key='feeds_fetched').update_one(upsert=True, key='feeds_fetched', value=feeds_fetched)
        
        premium_users = Profile.objects.filter(last_seen_on__gte=last_day, is_premium=True).count()
        cls.objects(key='premium_users').update_one(upsert=True, key='premium_users', value=premium_users)
        
        standard_users = Profile.objects.filter(last_seen_on__gte=last_day, is_premium=False).count()
        cls.objects(key='standard_users').update_one(upsert=True, key='standard_users', value=standard_users)

        now = datetime.datetime.now()
        sites_loaded = []
        avg_time_taken = []
        for hour in range(24):
            start_hours_ago = now - datetime.timedelta(hours=hour)
            end_hours_ago = now - datetime.timedelta(hours=hour+1)
            aggregates = dict(count=Count('loadtime'), avg=Avg('loadtime'))
            load_times = FeedLoadtime.objects.filter(
                date_accessed__lte=start_hours_ago, 
                date_accessed__gte=end_hours_ago
            ).aggregate(**aggregates)
            sites_loaded.append(load_times['count'] or 0)
            avg_time_taken.append(load_times['avg'] or 0)
        sites_loaded.reverse()
        avg_time_taken.reverse()
        cls.objects(key='sites_loaded').update_one(upsert=True, key='sites_loaded', value=json.encode(sites_loaded))
        cls.objects(key='avg_time_taken').update_one(upsert=True, key='avg_time_taken', value=json.encode(avg_time_taken))
        cls.objects(key='latest_sites_loaded').update_one(upsert=True, key='latest_sites_loaded', value=sites_loaded[-1])
        cls.objects(key='latest_avg_time_taken').update_one(upsert=True, key='latest_avg_time_taken', value=avg_time_taken[-1])
        print sites_loaded, avg_time_taken
        print max(sites_loaded), max(avg_time_taken)
        cls.objects(key='max_sites_loaded').update_one(upsert=True, key='max_sites_loaded', value=max(sites_loaded))
        cls.objects(key='max_avg_time_taken').update_one(upsert=True, key='max_avg_time_taken', value=max(avg_time_taken))
        