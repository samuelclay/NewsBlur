from django.db.models.manager import Manager
from query import CachedQuerySet

class CacheManager(Manager):
    """
    A manager to store and retrieve cached objects using CACHE_BACKEND

    <string key_prefix> -- the key prefix for all cached objects on this model. [default: db_table]
    <int timeout> -- in seconds, the maximum time before data is invalidated. [default: DEFAULT_CACHE_TIME]
    """
    def __init__(self, *args, **kwargs):
        self.key_prefix = kwargs.pop('key_prefix', None)
        self.timeout = kwargs.pop('timeout', None)
        super(CacheManager, self).__init__(*args, **kwargs)

    def get_query_set(self):
        return CachedQuerySet(model=self.model, timeout=self.timeout, key_prefix=self.key_prefix)

    def cache(self, *args, **kwargs):
        return self.get_query_set().cache(*args, **kwargs)

    def clean(self, *args, **kwargs):
        # Use reset instead if you are using memcached, as clean makes no sense (extra bandwidth when
        # memcached will automatically clean iself).
        return self.get_query_set().clean(*args, **kwargs)

    def reset(self, *args, **kwargs):
        return self.get_query_set().reset(*args, **kwargs)
