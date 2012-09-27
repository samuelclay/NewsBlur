import datetime
import mongoengine as mongo
import urllib2
from django.conf import settings
from apps.rss_feeds.models import MFeedFetchHistory, MPageFetchHistory, MFeedPushHistory
from apps.social.models import MSharedStory
from apps.profile.models import Profile
from utils import json_functions as json
from utils import db_functions

class MStatistics(mongo.Document):
    key   = mongo.StringField(unique=True)
    value = mongo.DynamicField()
    
    meta = {
        'collection': 'statistics',
        'allow_inheritance': False,
        'indexes': ['key'],
    }
    
    def __unicode__(self):
        return "%s: %s" % (self.key, self.value)
    
    @classmethod
    def get(cls, key, default=None):
        obj = cls.objects.filter(key=key).first()
        if not obj:
            return default
        return obj.value

    @classmethod
    def set(cls, key, value):
        obj, _ = cls.objects.get_or_create(key=key)
        obj.value = value
        obj.save()
    
    @classmethod
    def all(cls):
        stats = cls.objects.all()
        values = dict([(stat.key, stat.value) for stat in stats])
        for key, value in values.items():
            if key in ('avg_time_taken', 'sites_loaded', 'stories_shared'):
                values[key] = json.decode(value)
            elif key in ('feeds_fetched', 'premium_users', 'standard_users', 'latest_sites_loaded',
                         'max_sites_loaded', 'max_stories_shared'):
                values[key] = int(value)
            elif key in ('latest_avg_time_taken', 'max_avg_time_taken'):
                values[key] = float(value)
        
        values['total_sites_loaded'] = sum(values['sites_loaded']) if 'sites_loaded' in values else 0
        values['total_stories_shared'] = sum(values['stories_shared']) if 'stories_shared' in values else 0

        return values
        
    @classmethod
    def collect_statistics(cls):
        now = datetime.datetime.now()
        cls.collect_statistics_feeds_fetched()
        print "Feeds Fetched: %s" % (datetime.datetime.now() - now)
        cls.collect_statistics_premium_users()
        print "Premiums: %s" % (datetime.datetime.now() - now)
        cls.collect_statistics_standard_users()
        print "Standard users: %s" % (datetime.datetime.now() - now)
        cls.collect_statistics_sites_loaded()
        print "Sites loaded: %s" % (datetime.datetime.now() - now)
        cls.collect_statistics_stories_shared()
        print "Stories shared: %s" % (datetime.datetime.now() - now)
        cls.collect_statistics_for_db()
        print "DB Stats: %s" % (datetime.datetime.now() - now)
        
    @classmethod
    def collect_statistics_feeds_fetched(cls):
        last_day = datetime.datetime.now() - datetime.timedelta(hours=24)
        last_month = datetime.datetime.now() - datetime.timedelta(days=30)
        
        feeds_fetched = MFeedFetchHistory.objects.filter(fetch_date__gte=last_day).count()
        cls.objects(key='feeds_fetched').update_one(upsert=True, set__key='feeds_fetched', set__value=feeds_fetched)
        pages_fetched = MPageFetchHistory.objects.filter(fetch_date__gte=last_day).count()
        cls.objects(key='pages_fetched').update_one(upsert=True, set__key='pages_fetched', set__value=pages_fetched)
        feeds_pushed = MFeedPushHistory.objects.filter(push_date__gte=last_day).count()
        cls.objects(key='feeds_pushed').update_one(upsert=True, set__key='feeds_pushed', set__value=feeds_pushed)
        
        from utils.feed_functions import timelimit, TimeoutError
        @timelimit(60)
        def delete_old_history():
            MFeedFetchHistory.objects(fetch_date__lt=last_day, status_code__in=[200, 304]).delete()
            MPageFetchHistory.objects(fetch_date__lt=last_day, status_code__in=[200, 304]).delete()
            MFeedFetchHistory.objects(fetch_date__lt=last_month).delete()
            MPageFetchHistory.objects(fetch_date__lt=last_month).delete()
            MFeedPushHistory.objects(push_date__lt=last_month).delete()
        try:
            delete_old_history()
        except TimeoutError:
            print "Timed out on deleting old history. Shit."
        
        return feeds_fetched
        
    @classmethod
    def collect_statistics_premium_users(cls):
        last_day = datetime.datetime.now() - datetime.timedelta(hours=24)
        
        premium_users = Profile.objects.filter(last_seen_on__gte=last_day, is_premium=True).count()
        cls.objects(key='premium_users').update_one(upsert=True, set__key='premium_users', set__value=premium_users)
        
        return premium_users
    
    @classmethod
    def collect_statistics_standard_users(cls):
        last_day = datetime.datetime.now() - datetime.timedelta(hours=24)
        
        standard_users = Profile.objects.filter(last_seen_on__gte=last_day, is_premium=False).count()
        cls.objects(key='standard_users').update_one(upsert=True, set__key='standard_users', set__value=standard_users)
        
        return standard_users
    
    @classmethod
    def collect_statistics_sites_loaded(cls):
        now = datetime.datetime.now()
        sites_loaded = []
        avg_time_taken = []
        
        for hour in range(24):
            start_hours_ago = now - datetime.timedelta(hours=hour)
            end_hours_ago = now - datetime.timedelta(hours=hour+1)
            
            load_times = settings.MONGOANALYTICSDB.nbanalytics.page_loads.aggregate([{
                "$match": {
                    "date": {
                        "$gte": end_hours_ago,
                        "$lte": start_hours_ago,
                    },
                    "path": {
                        "$in": [
                            "/reader/feed/",
                            "/social/stories/",
                            "/reader/river_stories/",
                            "/social/river_stories/",
                        ]
                    }
                },
            }, {
                "$group": {
                    "_id"   : 1,
                    "count" : {"$sum": 1},
                    "avg"   : {"$avg": "$duration"},
                },
            }])

            count = 0
            avg = 0
            if load_times['result']:
                count = load_times['result'][0]['count']
                avg = load_times['result'][0]['avg']
                
            sites_loaded.append(count)
            avg_time_taken.append(avg)

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
            cls.objects(key=key).update_one(upsert=True, set__key=key, set__value=value)
            
    @classmethod
    def collect_statistics_stories_shared(cls):
        now = datetime.datetime.now()
        stories_shared = []
        
        for hour in range(24):
            start_hours_ago = now - datetime.timedelta(hours=hour)
            end_hours_ago = now - datetime.timedelta(hours=hour+1)
            shares = MSharedStory.objects.filter(
                shared_date__lte=start_hours_ago, 
                shared_date__gte=end_hours_ago
            ).count()
            stories_shared.append(shares)

        stories_shared.reverse()
        
        values = (
            ('stories_shared',        json.encode(stories_shared)),
            ('latest_stories_shared', stories_shared[-1]),
            ('max_stories_shared',    max(stories_shared)),
        )
        for key, value in values:
            cls.objects(key=key).update_one(upsert=True, set__key=key, set__value=value)
    
    @classmethod
    def collect_statistics_for_db(cls):
        lag = db_functions.mongo_max_replication_lag(settings.MONGODB)
        cls.set('mongodb_replication_lag', lag)
        

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
            for feedback in data:
                # Convert unicode to strings.
                fb = dict([(str(k), v) for k, v in feedback.items()])
                cls.objects.create(**fb)
    
    @classmethod
    def all(cls):
        feedbacks = cls.objects.all()[:4]

        return feedbacks

class MAnalyticsPageLoad(mongo.Document):
    date = mongo.DateTimeField(default=datetime.datetime.now)
    username = mongo.StringField()
    user_id = mongo.IntField()
    is_premium = mongo.BooleanField()
    platform = mongo.StringField()
    path = mongo.StringField()
    duration = mongo.FloatField()
    server = mongo.StringField()
    
    meta = {
        'db_alias': 'nbanalytics',
        'collection': 'page_loads',
        'allow_inheritance': False,
        'indexes': ['path', 'date', 'platform', 'user_id', 'server'],
        'ordering': ['date'],
    }
    
    def __unicode__(self):
        return "%s / %s: (%.4s) %s" % (self.username, self.platform, self.duration, self.path)
        
    @classmethod
    def add(cls, user, is_premium, platform, path, duration):
        if user.is_anonymous():
            username = None
            user_id = 0
        else:
            username = user.username
            user_id = user.pk
            
        path = cls.clean_path(path)
        server_name = settings.SERVER_NAME
        
        cls.objects.create(username=username, user_id=user_id, is_premium=is_premium,
                           platform=platform, path=path, duration=duration, server=server_name)
    
    @classmethod
    def clean_path(cls, path):
        if not path:
            return
            
        if path.startswith('/reader/feed'):
            path = '/reader/feed/'
        elif path.startswith('/social/stories'):
            path = '/social/stories/'
        elif path.startswith('/reader/river_stories'):
            path = '/reader/river_stories/'
        elif path.startswith('/social/river_stories'):
            path = '/social/river_stories/'
        elif path.startswith('/reader/page/'):
            path = '/reader/page/'
        elif path.startswith('/api/check_share_on_site'):
            path = '/api/check_share_on_site/'
            
        return path
        
    @classmethod
    def fetch_stats(cls, stat_key, stat_value):
        stats = cls.objects.filter(**{stat_key: stat_value})
        return cls.calculate_stats(stats)
        
    @classmethod
    def calculate_stats(cls, stats):
        return cls.aggregate(**stats)

    @classmethod
    def clean(cls, days=1):
        last_day = datetime.datetime.now() - datetime.timedelta(days=days)
        
        from utils.feed_functions import timelimit, TimeoutError
        @timelimit(60)
        def delete_old_history():
            cls.objects(date__lte=last_day).delete()
            cls.objects(date__lte=last_day).delete()
        try:
            delete_old_history()
        except TimeoutError:
            print "Timed out on deleting old history. Shit."
        

class MAnalyticsFetcher(mongo.Document):
    date = mongo.DateTimeField(default=datetime.datetime.now)
    feed_id = mongo.IntField()
    feed_fetch = mongo.FloatField()
    feed_process = mongo.FloatField()
    page = mongo.FloatField()
    icon = mongo.FloatField()
    total = mongo.FloatField()
    server = mongo.StringField()
    feed_code = mongo.IntField()
    
    meta = {
        'db_alias': 'nbanalytics',
        'collection': 'feed_fetches',
        'allow_inheritance': False,
        'indexes': ['date', 'feed_id', 'server', 'feed_code'],
        'ordering': ['date'],
    }
    
    def __unicode__(self):
        return "%s: %.4s+%.4s+%.4s+%.4s = %.4ss" % (self.feed_id, self.feed_fetch,
                                                    self.feed_process,
                                                    self.page, 
                                                    self.icon,
                                                    self.total)
        
    @classmethod
    def add(cls, feed_id, feed_fetch, feed_process, 
            page, icon, total, feed_code):
        server_name = settings.SERVER_NAME
        if 'app' in server_name: return
        
        if icon and page:
            icon -= page
        if page and feed_process:
            page -= feed_process
        elif page and feed_fetch:
            page -= feed_fetch
        if feed_process and feed_fetch:
            feed_process -= feed_fetch
        
        cls.objects.create(feed_id=feed_id, feed_fetch=feed_fetch,
                           feed_process=feed_process, 
                           page=page, icon=icon, total=total,
                           server=server_name, feed_code=feed_code)
    
    @classmethod
    def calculate_stats(cls, stats):
        return cls.aggregate(**stats)

    @classmethod
    def clean(cls, days=1):
        last_day = datetime.datetime.now() - datetime.timedelta(days=days)
        
        from utils.feed_functions import timelimit, TimeoutError
        @timelimit(60)
        def delete_old_history():
            cls.objects(date__lte=last_day).delete()
            cls.objects(date__lte=last_day).delete()
        try:
            delete_old_history()
        except TimeoutError:
            print "Timed out on deleting old history. Shit."
        
