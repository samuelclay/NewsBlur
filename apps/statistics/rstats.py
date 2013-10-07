import redis
import datetime
import re
from collections import defaultdict
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
    
    @classmethod
    def sample(cls, sample=1000, pool=None):
        if not pool:
            pool = settings.REDIS_STORY_HASH_POOL

        r             = redis.Redis(connection_pool=pool)
        keys          = set()
        errors        = set()
        prefixes      = defaultdict(set)
        sizes         = defaultdict(int)
        prefixes_ttls = defaultdict(lambda: defaultdict(int))
        prefix_re     = re.compile(r"(\w+):(.*)")

        p             = r.pipeline()
        [p.randomkey() for _ in range(sample)]
        keys          = set(p.execute())

        p             = r.pipeline()
        [p.ttl(key) for key in keys]
        ttls          = p.execute()

        dump = [r.execute_command('dump', key) for key in keys]
        
        for k, key in enumerate(keys):
            match = prefix_re.match(key)
            if not match or dump[k] is None:
                errors.add(key)
                continue
            prefix, rest = match.groups()
            prefixes[prefix].add(rest)
            sizes[prefix] += len(dump[k])
            ttl = ttls[k]
            if ttl < 0: # Never expire
                prefixes_ttls[prefix]['-'] += 1
            elif ttl == 0:
                prefixes_ttls[prefix]['X'] += 1
            elif ttl < 60*60: # 1 hour
                prefixes_ttls[prefix]['1h'] += 1
            elif ttl < 60*60*24:
                prefixes_ttls[prefix]['1d'] += 1
            elif ttl < 60*60*24*7:
                prefixes_ttls[prefix]['1w'] += 1
            elif ttl < 60*60*24*14:
                prefixes_ttls[prefix]['2w'] += 1
            elif ttl < 60*60*24*30:
                prefixes_ttls[prefix]['4w'] += 1
            else:
                prefixes_ttls[prefix]['4w+'] += 1
        
        keys_count = len(keys)
        total_size = float(sum([k for k in sizes.values()]))
        print " ---> %s total keys" % keys_count
        for prefix, rest in prefixes.items():
            total_expiring = sum([k for p, k in dict(prefixes_ttls[prefix]).items() if p != "-"])
            print " ---> %4s: (%.4s%% keys - %.4s%% space) %s keys (%s expiring: %s)" % (prefix, 100. * (len(rest) / float(keys_count)), 100 * (sizes[prefix] / total_size), len(rest), total_expiring, dict(prefixes_ttls[prefix]))
        print " ---> %s errors: %s" % (len(errors), errors)

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
   
