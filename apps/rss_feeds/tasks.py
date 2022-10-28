import datetime
import os
import shutil
import time
import redis
from newsblur_web.celeryapp import app
from celery.exceptions import SoftTimeLimitExceeded
from utils import log as logging
from django.conf import settings
from apps.profile.middleware import DBProfilerMiddleware
from utils.redis_raw_log_middleware import RedisDumpMiddleware
FEED_TASKING_MAX = 10000

@app.task(name='task-feeds')
def TaskFeeds():
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
    logging.debug(" ---> ~FBFeeds being tasked: ~SB%s" % feeds)

@app.task(name='task-broken-feeds')
def TaskBrokenFeeds():
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
            r.zincrby('error_feeds', 1, feed_id)
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
        
@app.task(name='update-feeds', time_limit=10*60, soft_time_limit=9*60, ignore_result=True)
def UpdateFeeds(feed_pks):
    from apps.rss_feeds.models import Feed
    from apps.statistics.models import MStatistics
    r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)

    mongodb_replication_lag = int(MStatistics.get('mongodb_replication_lag', 0))
    compute_scores = bool(mongodb_replication_lag < 10)
    
    profiler = DBProfilerMiddleware()
    profiler_activated = profiler.process_celery()
    if profiler_activated:
        settings.MONGO_COMMAND_LOGGER.process_celery(profiler)
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
        except SoftTimeLimitExceeded as e:
            feed.save_feed_history(505, 'Timeout', e)
            logging.info(" ---> [%-30s] ~BR~FWTime limit hit!~SB~FR Moving on to next feed..." % feed)
        if profiler_activated: profiler.process_celery_finished()

@app.task(name='new-feeds', time_limit=10*60, soft_time_limit=9*60, ignore_result=True)
def NewFeeds(feed_pks):
    from apps.rss_feeds.models import Feed
    if not isinstance(feed_pks, list):
        feed_pks = [feed_pks]
    
    options = {}
    for feed_pk in feed_pks:
        feed = Feed.get_by_id(feed_pk)
        if not feed: continue
        feed.update(options=options)

@app.task(name='push-feeds', ignore_result=True)
def PushFeeds(feed_id, xml):
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

@app.task()
def ScheduleImmediateFetches(feed_ids, user_id=None):
    from apps.rss_feeds.models import Feed
    
    if not isinstance(feed_ids, list):
        feed_ids = [feed_ids]
    
    Feed.schedule_feed_fetches_immediately(feed_ids, user_id=user_id)


@app.task()
def SchedulePremiumSetup(feed_ids):
    from apps.rss_feeds.models import Feed
    
    if not isinstance(feed_ids, list):
        feed_ids = [feed_ids]
    
    Feed.setup_feeds_for_premium_subscribers(feed_ids)
    
@app.task()
def ScheduleCountTagsForUser(user_id):
    from apps.rss_feeds.models import MStarredStoryCounts
    
    MStarredStoryCounts.count_for_user(user_id)
