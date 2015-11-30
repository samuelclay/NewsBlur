import datetime
import mongoengine as mongo
import urllib2
import redis
from django.conf import settings
from apps.social.models import MSharedStory
from apps.profile.models import Profile
from apps.statistics.rstats import RStats, round_time
from utils import json_functions as json
from utils import db_functions
from utils import log as logging

class MStatistics(mongo.Document):
    key   = mongo.StringField(unique=True)
    value = mongo.DynamicField()
    expiration_date = mongo.DateTimeField()
    
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
        if obj.expiration_date and obj.expiration_date < datetime.datetime.now():
            obj.delete()
            return default
        return obj.value

    @classmethod
    def set(cls, key, value, expiration_sec=None):
        try:
            obj = cls.objects.get(key=key)
        except cls.DoesNotExist:
            obj = cls.objects.create(key=key)
        obj.value = value
        if expiration_sec:
            obj.expiration_date = datetime.datetime.now() + datetime.timedelta(seconds=expiration_sec)
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
        cls.collect_statistics_feeds_fetched()
        print "Feeds Fetched: %s" % (datetime.datetime.now() - now)
        
    @classmethod
    def collect_statistics_feeds_fetched(cls):
        feeds_fetched = RStats.count('feed_fetch', hours=24)
        cls.objects(key='feeds_fetched').update_one(upsert=True, 
                                                    set__key='feeds_fetched',
                                                    set__value=feeds_fetched)
        
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
        now = round_time(datetime.datetime.now(), round_to=60)
        sites_loaded = []
        avg_time_taken = []
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

        for hour in range(24):
            start_hours_ago = now - datetime.timedelta(hours=hour+1)
    
            pipe = r.pipeline()
            for m in range(60):
                minute = start_hours_ago + datetime.timedelta(minutes=m)
                key = "%s:%s" % (RStats.stats_type('page_load'), minute.strftime('%s'))
                pipe.get("%s:s" % key)
                pipe.get("%s:a" % key)
    
            times = pipe.execute()
    
            counts = [int(c) for c in times[::2] if c]
            avgs = [float(a) for a in times[1::2] if a]
            
            if counts and avgs:
                count = sum(counts)
                avg = round(sum(avgs) / count, 3)
            else:
                count = 0
                avg = 0

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
        
        now = round_time(datetime.datetime.now(), round_to=60)
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        db_times = {}
        latest_db_times = {}
        
        for db in ['sql', 'mongo', 'redis']:
            db_times[db] = []
            for hour in range(24):
                start_hours_ago = now - datetime.timedelta(hours=hour+1)
    
                pipe = r.pipeline()
                for m in range(60):
                    minute = start_hours_ago + datetime.timedelta(minutes=m)
                    key = "DB:%s:%s" % (db, minute.strftime('%s'))
                    pipe.get("%s:c" % key)
                    pipe.get("%s:t" % key)
    
                times = pipe.execute()
    
                counts = [int(c or 0) for c in times[::2]]
                avgs = [float(a or 0) for a in times[1::2]]
                if counts and avgs:
                    count = sum(counts)
                    avg = round(sum(avgs) / count, 3) if count else 0
                else:
                    count = 0
                    avg = 0
                
                if hour == 0:
                    latest_count = float(counts[-1]) if len(counts) else 0
                    latest_avg = float(avgs[-1]) if len(avgs) else 0
                    latest_db_times[db] = latest_avg / latest_count if latest_count else 0
                db_times[db].append(avg)

            db_times[db].reverse()

        values = (
            ('avg_sql_times',           json.encode(db_times['sql'])),
            ('avg_mongo_times',         json.encode(db_times['mongo'])),
            ('avg_redis_times',         json.encode(db_times['redis'])),
            ('latest_sql_avg',          latest_db_times['sql']),
            ('latest_mongo_avg',        latest_db_times['mongo']),
            ('latest_redis_avg',        latest_db_times['redis']),
        )
        for key, value in values:
            cls.objects(key=key).update_one(upsert=True, set__key=key, set__value=value)


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
        try:
            data = urllib2.urlopen('https://getsatisfaction.com/newsblur/topics.widget').read()
        except (urllib2.HTTPError), e:
            logging.debug(" ***> Failed to collect feedback: %s" % e)
            return
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
                fb['url'] = fb['url'].replace('?utm_medium=widget&utm_source=widget_newsblur', "")
                cls.objects.create(**fb)
    
    @classmethod
    def all(cls):
        feedbacks = cls.objects.all()[:4]

        return feedbacks


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
