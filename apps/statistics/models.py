import datetime
import mongoengine as mongo
import urllib2
from django.db.models import Avg, Count
from apps.rss_feeds.models import MFeedFetchHistory, MPageFetchHistory, FeedLoadtime
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
        cls.collect_statistics_feeds_fetched(last_day)
        cls.collect_statistics_premium_users(last_day)
        cls.collect_statistics_standard_users(last_day)
        cls.collect_statistics_sites_loaded(last_day)
        
    @classmethod
    def collect_statistics_feeds_fetched(cls, last_day=None):
        if not last_day:
            last_day = datetime.datetime.now() - datetime.timedelta(hours=24)
        
        feeds_fetched = MFeedFetchHistory.objects(fetch_date__gte=last_day).count()
        cls.objects(key='feeds_fetched').update_one(upsert=True, key='feeds_fetched', value=feeds_fetched)
        
        old_fetch_histories = MFeedFetchHistory.objects(fetch_date__lte=last_day)
        for history in old_fetch_histories:
            history.delete()
        old_page_histories = MPageFetchHistory.objects(fetch_date__lte=last_day)
        for history in old_page_histories:
            history.delete()
        
        return feeds_fetched
        
    @classmethod
    def collect_statistics_premium_users(cls, last_day=None):
        if not last_day:
            last_day = datetime.datetime.now() - datetime.timedelta(hours=24)
            
        premium_users = Profile.objects.filter(last_seen_on__gte=last_day, is_premium=True).count()
        cls.objects(key='premium_users').update_one(upsert=True, key='premium_users', value=premium_users)
        
        return premium_users
    
    @classmethod
    def collect_statistics_standard_users(cls, last_day=None):
        if not last_day:
            last_day = datetime.datetime.now() - datetime.timedelta(hours=24)
        
        standard_users = Profile.objects.filter(last_seen_on__gte=last_day, is_premium=False).count()
        cls.objects(key='standard_users').update_one(upsert=True, key='standard_users', value=standard_users)
        
        return standard_users
    
    @classmethod
    def collect_statistics_sites_loaded(cls, last_day=None):
        if not last_day:
            last_day = datetime.datetime.now() - datetime.timedelta(hours=24)
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
        
        values = (
            ('sites_loaded',            json.encode(sites_loaded)),
            ('avg_time_taken',          json.encode(avg_time_taken)),
            ('latest_sites_loaded',     sites_loaded[-1]),
            ('latest_avg_time_taken',   avg_time_taken[-1]),
            ('max_sites_loaded',        max(sites_loaded)),
            ('max_avg_time_taken',      max(1, max(avg_time_taken))),
        )
        for key, value in values:
            cls.objects(key=key).update_one(upsert=True, key=key, value=value)

class MFeedback(mongo.Document):
    date    = mongo.StringField()
    summary = mongo.StringField()
    subject = mongo.StringField()
    url     = mongo.StringField()
    style   = mongo.StringField()
    order   = mongo.IntField()
    
    meta = {
        'collection': 'feedback',
        'allow_inheritance': False,
        'indexes': ['style'],
        'ordering': ['order'],
    }
    
    def __unicode__(self):
        return "%s: (%s) %s" % (self.style, self.date, self.subject)
        
    @classmethod
    def collect_feedback(cls):
        data = urllib2.urlopen('https://getsatisfaction.com/newsblur/topics.widget').read()
        data = json.decode(data[1:-1])
        i    = 0
        if len(data):
            cls.objects.delete()
            for feedback in data:
                feedback['order'] = i
                i += 1
                for removal in ['about', 'less than']:
                    if removal in feedback['date']:
                        feedback['date'] = feedback['date'].replace(removal, '')
            [cls.objects.create(**feedback) for feedback in data]
    
    @classmethod
    def all(cls):
        feedbacks = cls.objects.all()[:5]

        return feedbacks