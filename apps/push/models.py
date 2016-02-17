# Adapted from djpubsubhubbub. See License: http://git.participatoryculture.org/djpubsubhubbub/tree/LICENSE

from datetime import datetime, timedelta
import feedparser
import requests
import re

from django.conf import settings
from django.db import models
import hashlib

from apps.push import signals
from apps.rss_feeds.models import Feed
from utils import log as logging
from utils.feed_functions import timelimit, TimeoutError

DEFAULT_LEASE_SECONDS = (10 * 24 * 60 * 60)  # 10 days

class PushSubscriptionManager(models.Manager):
    
    @timelimit(5)
    def subscribe(self, topic, feed, hub=None, callback=None,
                  lease_seconds=None, force_retry=False):
        if hub is None:
            hub = self._get_hub(topic)

        if hub is None:
            raise TypeError('hub cannot be None if the feed does not provide it')

        if lease_seconds is None:
            lease_seconds = getattr(settings, 'PUBSUBHUBBUB_LEASE_SECONDS',
                                   DEFAULT_LEASE_SECONDS)

        feed = Feed.get_by_id(feed.pk)
        subscription, created = self.get_or_create(feed=feed)
        signals.pre_subscribe.send(sender=subscription, created=created)
        subscription.set_expiration(lease_seconds)
        if len(topic) < 200:
            subscription.topic = topic
        else:
            subscription.topic = feed.feed_link[:200]
        subscription.hub = hub
        subscription.save()
        
        if callback is None:
            # try:
            #     callback_path = reverse('push-callback', args=(subscription.pk,))
            # except Resolver404:
            #     raise TypeError('callback cannot be None if there is not a reverable URL')
            # else:
            #     # callback = 'http://' + Site.objects.get_current() + callback_path
            callback = "http://push.newsblur.com/push/%s" % subscription.pk # + callback_path

        try:
            response = self._send_request(hub, {
                'hub.mode'          : 'subscribe',
                'hub.callback'      : callback,
                'hub.topic'         : topic,
                'hub.verify'        : ['async', 'sync'],
                'hub.verify_token'  : subscription.generate_token('subscribe'),
                'hub.lease_seconds' : lease_seconds,
            })
        except requests.ConnectionError:
            response = None

        if response and response.status_code == 204:
            subscription.verified = True
        elif response and response.status_code == 202: # async verification
            subscription.verified = False
        else:
            error = response and response.text or ""
            if not force_retry and 'You may only subscribe to' in error:
                extracted_topic = re.search("You may only subscribe to (.*?) ", error)
                if extracted_topic:
                    subscription = self.subscribe(extracted_topic.group(1), 
                                                  feed=feed, hub=hub, force_retry=True)
            else:
                logging.debug(u'   ---> [%-30s] ~FR~BKFeed failed to subscribe to push: %s (code: %s)' % (
                              unicode(subscription.feed)[:30], error[:100], response and response.status_code))

        subscription.save()
        feed.setup_push()
        if subscription.verified:
            signals.verified.send(sender=subscription)
        return subscription


    def _get_hub(self, topic):
        parsed = feedparser.parse(topic)
        for link in parsed.feed.links:
            if link['rel'] == 'hub':
                return link['href']

    def _send_request(self, url, data):
        return requests.post(url, data=data)

class PushSubscription(models.Model):
    feed = models.OneToOneField(Feed, db_index=True, related_name='push')
    hub = models.URLField(db_index=True)
    topic = models.URLField(db_index=True)
    verified = models.BooleanField(default=False)
    verify_token = models.CharField(max_length=60)
    lease_expires = models.DateTimeField(default=datetime.now)

    objects = PushSubscriptionManager()

    # class Meta:
    #     unique_together = [
    #         ('hub', 'topic')
    #         ]
    
    def unsubscribe(self):
        feed = self.feed
        self.delete()
        feed.setup_push()
        
    def set_expiration(self, lease_seconds):
        self.lease_expires = datetime.now() + timedelta(
            seconds=lease_seconds)
        self.save()

    def generate_token(self, mode):
        assert self.pk is not None, \
            'Subscription must be saved before generating token'
        token = mode[:20] + hashlib.sha1('%s%i%s' % (
                settings.SECRET_KEY, self.pk, mode)).hexdigest()
        self.verify_token = token
        self.save()
        return token
    
    def check_urls_against_pushed_data(self, parsed):
        if hasattr(parsed.feed, 'links'): # single notification
            hub_url = self.hub
            self_url = self.topic
            for link in parsed.feed.links:
                href = link.get('href', '')
                if any(w in href for w in ['wp-admin', 'wp-cron']):
                    continue
                    
                if link['rel'] == 'hub':
                    hub_url = link['href']
                elif link['rel'] == 'self':
                    self_url = link['href']
            
            if hub_url and hub_url.startswith('//'):
                hub_url = "http:%s" % hub_url
            
            needs_update = False
            if hub_url and self.hub != hub_url:
                # hub URL has changed; let's update our subscription
                needs_update = True
            elif self_url != self.topic:
                # topic URL has changed
                needs_update = True

            if needs_update:
                logging.debug(u'   ---> [%-30s] ~FR~BKUpdating PuSH hub/topic: %s / %s' % (
                              unicode(self.feed)[:30], hub_url, self_url))
                expiration_time = self.lease_expires - datetime.now()
                seconds = expiration_time.days*86400 + expiration_time.seconds
                try:
                    PushSubscription.objects.subscribe(
                        self_url, feed=self.feed, hub=hub_url,
                        lease_seconds=seconds)
                except TimeoutError, e:
                    logging.debug(u'   ---> [%-30s] ~FR~BKTimed out updating PuSH hub/topic: %s / %s' % (
                                  unicode(self.feed)[:30], hub_url, self_url))
                    
                    
    def __unicode__(self):
        if self.verified:
            verified = u'verified'
        else:
            verified = u'unverified'
        return u'to %s on %s: %s' % (
            self.topic, self.hub, verified)

    def __str__(self):
        return str(unicode(self))
