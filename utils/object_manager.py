from django.db import models
from django.contrib.sites.models import Site
from django.core.cache import cache
 
CACHE_EXPIRES = 5 * 60 # 10 minutes
 
def get_object_manager(model_name):
    class ObjectManager(models.Manager):
        
        def get_query_set(self, *args, **kwargs):
            cache_key = '%s%d%s%s' % (
                model_name,
                Site.objects.get_current().id, # unique for site
                ''.join([str(a) for a in args]), # unique for arguments
                ''.join('%s%s' % (str(k), str(v)) for k, v in kwargs.iteritems())
            )
 
            object_list = cache.get(cache_key)
            print "Cache?",  cache_key, type(object_list)
            if object_list is None:
                print "Caching: " + str(cache_key)
                object_list = super(ObjectManager, self).get_query_set(*args, **kwargs)
                cache.set(cache_key, object_list, CACHE_EXPIRES)
            return object_list
            
    return ObjectManager()