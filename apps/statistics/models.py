import datetime
import mongoengine as mongo
import urllib.request, urllib.error, urllib.parse
import redis
import dateutil
import requests
from django.conf import settings
from apps.social.models import MSharedStory
from apps.profile.models import Profile
from apps.statistics.rstats import RStats, round_time
from utils.story_functions import relative_date
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
    
    def __str__(self):
        return "%s: %s" % (self.key, self.value)
    
    @classmethod
    def get(cls, key, default=None, set_default=False, expiration_sec=None):
        obj = cls.objects.filter(key=key).first()
        if not obj:
            if set_default:
                default = default()
                cls.set(key, default, expiration_sec=expiration_sec)
            return default
        if obj.expiration_date and obj.expiration_date < datetime.datetime.now():
            obj.delete()
            if set_default:
                default = default()
                cls.set(key, default, expiration_sec=expiration_sec)
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
        for key, value in list(values.items()):
            if key in ('avg_time_taken', 'sites_loaded', 'stories_shared'):
                values[key] = json.decode(value)
            elif key in ('feeds_fetched', 'premium_users', 'standard_users', 'latest_sites_loaded',
                         'max_sites_loaded', 'max_stories_shared'):
                values[key] = int(value)
            elif key in ('latest_avg_time_taken', 'max_avg_time_taken', 'last_1_min_time_taken'):
                values[key] = float(value)
        
        values['total_sites_loaded'] = sum(values['sites_loaded']) if 'sites_loaded' in values else 0
        values['total_stories_shared'] = sum(values['stories_shared']) if 'stories_shared' in values else 0

        return values
        
    @classmethod
    def collect_statistics(cls):
        now = datetime.datetime.now()
        cls.collect_statistics_premium_users()
        # if settings.DEBUG:
        #     print("Premiums: %s" % (datetime.datetime.now() - now))
        cls.collect_statistics_standard_users()
        # if settings.DEBUG:
        #     print("Standard users: %s" % (datetime.datetime.now() - now))
        cls.collect_statistics_sites_loaded()
        # if settings.DEBUG:
        #     print("Sites loaded: %s" % (datetime.datetime.now() - now))
        cls.collect_statistics_stories_shared()
        # if settings.DEBUG:
        #     print("Stories shared: %s" % (datetime.datetime.now() - now))
        cls.collect_statistics_for_db()
        # if settings.DEBUG:
        #     print("DB Stats: %s" % (datetime.datetime.now() - now))
        cls.collect_statistics_feeds_fetched()
        # if settings.DEBUG:
        #     print("Feeds Fetched: %s" % (datetime.datetime.now() - now))
        
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
        last_1_min_time_taken = 0
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

        for hours_ago in range(24):
            start_hours_ago = now - datetime.timedelta(hours=hours_ago+1)
    
            pipe = r.pipeline()
            for m in range(60):
                minute = start_hours_ago + datetime.timedelta(minutes=m)
                key = "%s:%s" % (RStats.stats_type('page_load'), minute.strftime('%s'))
                pipe.get("%s:s" % key)
                pipe.get("%s:a" % key)
    
            times = pipe.execute()
    
            counts = [int(c) for c in times[::2] if c]
            avgs = [float(a) for a in times[1::2] if a]
            
            if hours_ago == 0:
                last_1_min_time_taken = round(sum(avgs[:1]) / max(1, sum(counts[:1])), 2)
                
            if counts and avgs:
                count = max(1, sum(counts))
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
            ('last_1_min_time_taken',   last_1_min_time_taken),
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
    def collect_statistics_for_db(cls, debug=False):
        lag = db_functions.mongo_max_replication_lag(settings.MONGODB)
        cls.set('mongodb_replication_lag', lag)
        
        now = round_time(datetime.datetime.now(), round_to=60)
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        db_times = {}
        latest_db_times = {}

        for db in ['sql',
                   'mongo',
                   'redis',
                   'redis_user',
                   'redis_story',
                   'redis_session',
                   'redis_pubsub',
                   'task_sql',
                   'task_mongo',
                   'task_redis',
                   'task_redis_user',
                   'task_redis_story',
                   'task_redis_session',
                   'task_redis_pubsub',
                   ]:
            db_times[db] = []
            for hour in range(24):
                start_hours_ago = now - datetime.timedelta(hours=hour+1)

                pipe = r.pipeline()
                for m in range(60):
                    minute = start_hours_ago + datetime.timedelta(minutes=m)
                    key = "DB:%s:%s" % (db, minute.strftime('%s'))
                    if debug:
                        print(" -> %s:c" % key)
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
            ('latest_redis_user_avg',   latest_db_times['redis_user']),
            ('latest_redis_story_avg',  latest_db_times['redis_story']),
            ('latest_redis_session_avg',latest_db_times['redis_session']),
            ('latest_redis_pubsub_avg', latest_db_times['redis_pubsub']),
            ('latest_task_sql_avg',     latest_db_times['task_sql']),
            ('latest_task_mongo_avg',   latest_db_times['task_mongo']),
            ('latest_task_redis_user_avg',   latest_db_times['task_redis_user']),
            ('latest_task_redis_story_avg',  latest_db_times['task_redis_story']),
            ('latest_task_redis_session_avg',latest_db_times['task_redis_session']),
            ('latest_task_redis_pubsub_avg', latest_db_times['task_redis_pubsub']),
        )
        for key, value in values:
            cls.objects(key=key).update_one(upsert=True, set__key=key, set__value=value)


class MFeedback(mongo.Document):
    date    = mongo.DateTimeField()
    date_short = mongo.StringField()
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
    
    CATEGORIES = {
        5: 'idea',
        6: 'problem',
        7: 'praise',
        8: 'question',
        9: 'admin',
        10: 'updates',
    }
    
    def __str__(self):
        return "%s: (%s) %s" % (self.style, self.date, self.subject)
        
    @classmethod
    def collect_feedback(cls):
        seen_posts = set()
        try:
            data = requests.get('https://forum.newsblur.com/posts.json', timeout=3).content
        except (urllib.error.HTTPError, requests.exceptions.ConnectTimeout) as e:
            logging.debug(" ***> Failed to collect feedback: %s" % e)
            return
        data = json.decode(data).get('latest_posts', "")

        if not len(data):
            print("No data!")
            return
            
        cls.objects.delete()
        post_count = 0
        for post in data:
            if post['topic_id'] in seen_posts: continue
            seen_posts.add(post['topic_id'])
            feedback = {}
            feedback['order'] = post_count
            post_count += 1
            feedback['date'] = dateutil.parser.parse(post['created_at']).replace(tzinfo=None)
            feedback['date_short'] = relative_date(feedback['date'])
            feedback['subject'] = post['topic_title']
            feedback['url'] = "https://forum.newsblur.com/t/%s/%s/%s" % (post['topic_slug'], post['topic_id'], post['post_number'])
            feedback['style'] = cls.CATEGORIES[post['category_id']]
            cls.objects.create(**feedback)
            # if settings.DEBUG:
            #     print("%s: %s (%s)" % (feedback['style'], feedback['subject'], feedback['date_short']))
            if post_count >= 4: break
    
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
    
    def __str__(self):
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


class MAnalyticsLoader(mongo.Document):
    date = mongo.DateTimeField(default=datetime.datetime.now)
    page_load = mongo.FloatField()
    server = mongo.StringField()
    
    meta = {
        'db_alias': 'nbanalytics',
        'collection': 'page_loads',
        'allow_inheritance': False,
        'indexes': ['date', 'server'],
        'ordering': ['date'],
    }
    
    def __str__(self):
        return "%s: %.4ss" % (self.server, self.page_load)
        
    @classmethod
    def add(cls, page_load):
        server_name = settings.SERVER_NAME

        cls.objects.create(page_load=page_load, server=server_name)
    
    @classmethod
    def calculate_stats(cls, stats):
        return cls.aggregate(**stats)
