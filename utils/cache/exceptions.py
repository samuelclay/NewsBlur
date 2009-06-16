class CachedModelException(Exception): pass


# Our invalidation classes
class CacheInvalidationWarning(CachedModelException): pass

class CacheMissingWarning(CacheInvalidationWarning):
    """
    CacheMissingWarning is thrown when we're trying to fetch a queryset
    and it's missing objects in the database.
    """
    pass

class CacheExpiredWarning(CacheInvalidationWarning):
    """
    CacheExpiredWarning is thrown when we're trying to fetch from the cache
    but the pre-expiration has been hit.
    """
    pass
