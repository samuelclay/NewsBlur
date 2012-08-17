import sys
from django.db import models
from django.contrib.auth.models import User
from apps.rss_feeds.models import DuplicateFeed
from utils import log as logging

class UserSubscriptionManager(models.Manager):
    def get(self, *args, **kwargs):
        try:
            return super(UserSubscriptionManager, self).get(*args, **kwargs)
        except self.model.DoesNotExist:
            if isinstance(kwargs.get('feed'), int):
                feed_id = kwargs.get('feed')
            elif 'feed' in kwargs:
                feed_id = kwargs['feed'].pk
            elif 'feed__pk' in kwargs:
                feed_id = kwargs['feed__pk']
            elif 'feed_id' in kwargs:
                feed_id = kwargs['feed_id']
            dupe_feed = DuplicateFeed.objects.filter(duplicate_feed_id=feed_id)
            if dupe_feed:
                feed = dupe_feed[0].feed
                if 'feed' in kwargs: 
                    kwargs['feed'] = feed
                elif 'feed__pk' in kwargs:
                    kwargs['feed__pk'] = feed.pk
                elif 'feed_id' in kwargs:
                    kwargs['feed_id'] = feed.pk
                user = kwargs.get('user')
                if isinstance(user, int):
                    user = User.objects.get(pk=user)
                logging.debug(" ---> [%s] ~BRFound dupe UserSubscription: ~SB%s (%s)" % (user and user.username, feed, feed_id))
                return super(UserSubscriptionManager, self).get(*args, **kwargs)
            else:
                exc_info = sys.exc_info()
                raise exc_info[0], None, exc_info[2]
