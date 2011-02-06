from django.db import models
from apps.rss_feeds.models import DuplicateFeed
from utils import log as logging

class UserSubscriptionManager(models.Manager):
    def get(self, *args, **kwargs):
        try:
            return super(UserSubscriptionManager, self).get(*args, **kwargs)
        except:
            dupe_feed = DuplicateFeed.objects.filter(duplicate_feed_id=kwargs['feed'].pk)
            if dupe_feed:
                feed = dupe_feed[0].feed
                kwargs['feed'] = feed
                logging.debug(" ---> [%s] ~BRFound dupe UserSubscription: ~SB%s" % (kwargs['user'].username, kwargs['feed']))
                return super(UserSubscriptionManager, self).get(*args, **kwargs)