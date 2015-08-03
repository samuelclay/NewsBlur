from django.conf import settings
import redis

from apps.social.models import *

r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
print "Redis: %s" % r