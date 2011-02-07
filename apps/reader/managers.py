from django.db import models
from apps.rss_feeds.models import DuplicateFeed
from utils import log as logging

class UserSubscriptionManager(models.Manager):
    def get(self, *args, **kwargs):
        try:
            return super(UserSubscriptionManager, self).get(*args, **kwargs)
        except:
            if 'feed' in kwargs:
                feed_id = kwargs['feed'].pk
            elif 'feed__pk' in kwargs:
                feed_id = kwargs['feed__pk']
            dupe_feed = DuplicateFeed.objects.filter(duplicate_feed_id=feed_id)
            if dupe_feed:
                feed = dupe_feed[0].feed
                if 'feed' in kwargs: 
                    kwargs['feed'] = feed
                elif 'feed__pk' in kwargs:
                    kwargs['feed__pk'] = feed.pk
                logging.debug(" ---> [%s] ~BRFound dupe UserSubscription: ~SB%s (%s)" % (kwargs['user'].username, feed, feed_id))
                return super(UserSubscriptionManager, self).get(*args, **kwargs)