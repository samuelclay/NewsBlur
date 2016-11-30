import datetime
import os
import shutil
import time
import redis
from celery.task import Task
from celery.exceptions import SoftTimeLimitExceeded
from utils import log as logging
from utils import s3_utils as s3
from django.conf import settings
from apps.profile.middleware import DBProfilerMiddleware
from utils.mongo_raw_log_middleware import MongoDumpMiddleware
from utils.redis_raw_log_middleware import RedisDumpMiddleware
FEED_TASKING_MAX = 10000

class TaskFeeds(Task):
    name = 'task-feeds'

    def run(self, **kwargs):
        from apps.rss_feeds.models import Feed        
        settings.LOG_TO_STREAM = True
        now = datetime.datetime.utcnow()
        start = time.time()
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        tasked_feeds_size = r.zcard('tasked_feeds')
        
        hour_ago = now - datetime.timedelta(hours=1)
        r.zremrangebyscore('fetched_feeds_last_hour', 0, int(hour_ago.strftime('%s')))
        
        now_timestamp = int(now.strftime("%s"))
        queued_feeds = r.zrangebyscore('scheduled_updates', 0, now_timestamp)
        r.zremrangebyscore('scheduled_updates', 0, now_timestamp)
        if not queued_feeds:
            logging.debug(" ---> ~SN~FB~BMNo feeds to queue! Exiting...")
            return
            
        r.sadd('queued_feeds', *queued_feeds)
        logging.debug(" ---> ~SN~FBQueuing ~SB%s~SN stale feeds (~SB%s~SN/~FG%s~FB~SN/%s tasked/queued/scheduled)" % (
                        len(queued_feeds),
                        r.zcard('tasked_feeds'),
                        r.scard('queued_feeds'),
                        r.zcard('scheduled_updates')))
        
        # Regular feeds
        if tasked_feeds_size < FEED_TASKING_MAX:
            feeds = r.srandmember('queued_feeds', FEED_TASKING_MAX)
            Feed.task_feeds(feeds, verbose=True)
            active_count = len(feeds)
        else:
            logging.debug(" ---> ~SN~FBToo many tasked feeds. ~SB%s~SN tasked." % tasked_feeds_size)
            active_count = 0
        
        logging.debug(" ---> ~SN~FBTasking %s feeds took ~SB%s~SN seconds (~SB%s~SN/~FG%s~FB~SN/%s tasked/queued/scheduled)" % (
                        active_count,
                        int((time.time() - start)),
                        r.zcard('tasked_feeds'),
                        r.scard('queued_feeds'),
                        r.zcard('scheduled_updates')))

class TaskBrokenFeeds(Task):
    name = 'task-broken-feeds'
    max_retries = 0
    ignore_result = True
    
    def run(self, **kwargs):
        from apps.rss_feeds.models import Feed        
        settings.LOG_TO_STREAM = True
        now = datetime.datetime.utcnow()
        start = time.time()
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        
        logging.debug(" ---> ~SN~FBQueuing broken feeds...")
        
        # Force refresh feeds
        refresh_feeds = Feed.objects.filter(
            active=True,
            fetched_once=False,
            active_subscribers__gte=1
        ).order_by('?')[:100]
        refresh_count = refresh_feeds.count()
        cp1 = time.time()
        
        logging.debug(" ---> ~SN~FBFound %s active, unfetched broken feeds" % refresh_count)

        # Mistakenly inactive feeds
        hours_ago = (now - datetime.timedelta(minutes=10)).strftime('%s')
        old_tasked_feeds = r.zrangebyscore('tasked_feeds', 0, hours_ago)
        inactive_count = len(old_tasked_feeds)
        if inactive_count:
            r.zremrangebyscore('tasked_feeds', 0, hours_ago)
            # r.sadd('queued_feeds', *old_tasked_feeds)
            for feed_id in old_tasked_feeds:
                r.zincrby('error_feeds', feed_id, 1)
                feed = Feed.get_by_id(feed_id)
                feed.set_next_scheduled_update()
        logging.debug(" ---> ~SN~FBRe-queuing ~SB%s~SN dropped/broken feeds (~SB%s/%s~SN queued/tasked)" % (
                        inactive_count,
                        r.scard('queued_feeds'),
                        r.zcard('tasked_feeds')))
        cp2 = time.time()
        
        old = now - datetime.timedelta(days=1)
        old_feeds = Feed.objects.filter(
            next_scheduled_update__lte=old, 
            active_subscribers__gte=1
        ).order_by('?')[:500]
        old_count = old_feeds.count()
        cp3 = time.time()
        
        logging.debug(" ---> ~SN~FBTasking ~SBrefresh:~FC%s~FB inactive:~FC%s~FB old:~FC%s~SN~FB broken feeds... (%.4s/%.4s/%.4s)" % (
            refresh_count,
            inactive_count,
            old_count,
            cp1 - start,
            cp2 - cp1,
            cp3 - cp2,
        ))
        
        Feed.task_feeds(refresh_feeds, verbose=False)
        Feed.task_feeds(old_feeds, verbose=False)
        
        logging.debug(" ---> ~SN~FBTasking broken feeds took ~SB%s~SN seconds (~SB%s~SN/~FG%s~FB~SN/%s tasked/queued/scheduled)" % (
                        int((time.time() - start)),
                        r.zcard('tasked_feeds'),
                        r.scard('queued_feeds'),
                        r.zcard('scheduled_updates')))
        
class UpdateFeeds(Task):
    name = 'update-feeds'
    max_retries = 0
    ignore_result = True
    time_limit = 10*60
    soft_time_limit = 9*60

    def run(self, feed_pks, **kwargs):
        from apps.rss_feeds.models import Feed
        from apps.statistics.models import MStatistics
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)

        mongodb_replication_lag = int(MStatistics.get('mongodb_replication_lag', 0))
        compute_scores = bool(mongodb_replication_lag < 10)
        
        profiler = DBProfilerMiddleware()
        profiler_activated = profiler.process_celery()
        if profiler_activated:
            mongo_middleware = MongoDumpMiddleware()
            mongo_middleware.process_celery(profiler)
            redis_middleware = RedisDumpMiddleware()
            redis_middleware.process_celery(profiler)
        
        options = {
            'quick': float(MStatistics.get('quick_fetch', 0)),
            'updates_off': MStatistics.get('updates_off', False),
            'compute_scores': compute_scores,
            'mongodb_replication_lag': mongodb_replication_lag,
        }
        
        if not isinstance(feed_pks, list):
            feed_pks = [feed_pks]
            
        for feed_pk in feed_pks:
            feed = Feed.get_by_id(feed_pk)
            if not feed or feed.pk != int(feed_pk):
                logging.info(" ---> ~FRRemoving feed_id %s from tasked_feeds queue, points to %s..." % (feed_pk, feed and feed.pk))
                r.zrem('tasked_feeds', feed_pk)
            if not feed:
                continue
            try:
                feed.update(**options)
            except SoftTimeLimitExceeded, e:
                feed.save_feed_history(505, 'Timeout', e)
                logging.info(" ---> [%-30s] ~BR~FWTime limit hit!~SB~FR Moving on to next feed..." % feed)
            if profiler_activated: profiler.process_celery_finished()

class NewFeeds(Task):
    name = 'new-feeds'
    max_retries = 0
    ignore_result = True
    time_limit = 10*60
    soft_time_limit = 9*60

    def run(self, feed_pks, **kwargs):
        from apps.rss_feeds.models import Feed
        if not isinstance(feed_pks, list):
            feed_pks = [feed_pks]
        
        options = {}
        for feed_pk in feed_pks:
            feed = Feed.get_by_id(feed_pk)
            if not feed: continue
            feed.update(options=options)

class PushFeeds(Task):
    name = 'push-feeds'
    max_retries = 0
    ignore_result = True

    def run(self, feed_id, xml, **kwargs):
        from apps.rss_feeds.models import Feed
        from apps.statistics.models import MStatistics
        
        mongodb_replication_lag = int(MStatistics.get('mongodb_replication_lag', 0))
        compute_scores = bool(mongodb_replication_lag < 60)
        
        options = {
            'feed_xml': xml,
            'compute_scores': compute_scores,
            'mongodb_replication_lag': mongodb_replication_lag,
        }
        feed = Feed.get_by_id(feed_id)
        if feed:
            feed.update(options=options)

class BackupMongo(Task):
    name = 'backup-mongo'
    max_retries = 0
    ignore_result = True
    
    def run(self, **kwargs):
        COLLECTIONS = "classifier_tag classifier_author classifier_feed classifier_title userstories starred_stories shared_stories category category_site sent_emails social_profile social_subscription social_services statistics feedback"

        date = time.strftime('%Y-%m-%d-%H-%M')
        collections = COLLECTIONS.split(' ')
        db_name = 'newsblur'
        dir_name = 'backup_mongo_%s' % date
        filename = '%s.tgz' % dir_name

        os.mkdir(dir_name)

        for collection in collections:
            cmd = 'mongodump  --db %s --collection %s -o %s' % (db_name, collection, dir_name)
            logging.debug(' ---> ~FMDumping ~SB%s~SN: %s' % (collection, cmd))
            os.system(cmd)

        cmd = 'tar -jcf %s %s' % (filename, dir_name)
        os.system(cmd)

        logging.debug(' ---> ~FRUploading ~SB~FM%s~SN~FR to S3...' % filename)
        s3.save_file_in_s3(filename)
        shutil.rmtree(dir_name)
        os.remove(filename)
        logging.debug(' ---> ~FRFinished uploading ~SB~FM%s~SN~FR to S3.' % filename)


class ScheduleImmediateFetches(Task):
    
    def run(self, feed_ids, user_id=None, **kwargs):
        from apps.rss_feeds.models import Feed
        
        if not isinstance(feed_ids, list):
            feed_ids = [feed_ids]
        
        Feed.schedule_feed_fetches_immediately(feed_ids, user_id=user_id)


class SchedulePremiumSetup(Task):
    
    def run(self, feed_ids, **kwargs):
        from apps.rss_feeds.models import Feed
        
        if not isinstance(feed_ids, list):
            feed_ids = [feed_ids]
        
        Feed.setup_feeds_for_premium_subscribers(feed_ids)
        
class ScheduleCountTagsForUser(Task):
    
    def run(self, user_id):
        from apps.rss_feeds.models import MStarredStoryCounts
        
        MStarredStoryCounts.count_for_user(user_id)
