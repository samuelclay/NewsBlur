import redis
import datetime
from django.conf import settings


class RStats:
    
    STATS_TYPE = {
        'page_load': 'PLT',
        'feed_fetch': 'FFH',
    }
    
    @classmethod
    def stats_type(cls, name):
        return cls.STATS_TYPE[name]
        
    @classmethod
    def add(cls, name, duration=None):
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        pipe = r.pipeline()
        minute = round_time(round_to=60)
        key = "%s:%s" % (cls.stats_type(name), minute.strftime('%s'))
        pipe.incr("%s:s" % key)
        if duration:
            pipe.incrbyfloat("%s:a" % key, duration)
            pipe.expireat("%s:a" % key, (minute + datetime.timedelta(days=2)).strftime("%s"))
        pipe.expireat("%s:s" % key, (minute + datetime.timedelta(days=2)).strftime("%s"))
        pipe.execute()
    
    @classmethod
    def clean_path(cls, path):
        if not path:
            return
            
        if path.startswith('/reader/feed/'):
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
    def count(cls, name, hours=24):
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        stats_type = cls.stats_type(name)
        now = datetime.datetime.now()
        pipe = r.pipeline()
        for minutes_ago in range(60*hours):
            dt_min_ago = now - datetime.timedelta(minutes=minutes_ago)
            minute = round_time(dt=dt_min_ago, round_to=60)
            key = "%s:%s" % (stats_type, minute.strftime('%s'))
            pipe.get("%s:s" % key)
        values = pipe.execute()
        total = sum(int(v) for v in values if v)
        return total


def round_time(dt=None, round_to=60):
   """Round a datetime object to any time laps in seconds
   dt : datetime.datetime object, default now.
   round_to : Closest number of seconds to round to, default 1 minute.
   Author: Thierry Husson 2012 - Use it as you want but don't blame me.
   """
   if dt == None : dt = datetime.datetime.now()
   seconds = (dt - dt.min).seconds
   rounding = (seconds+round_to/2) // round_to * round_to
   return dt + datetime.timedelta(0,rounding-seconds,-dt.microsecond)
   
