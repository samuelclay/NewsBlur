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
   
