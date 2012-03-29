# Adapted from djpubsubhubbub. See License: http://git.participatoryculture.org/djpubsubhubbub/tree/LICENSE

from datetime import datetime
import feedparser

from django.http import HttpResponse, Http404
from django.shortcuts import get_object_or_404

from apps.push.models import PushSubscription
from apps.push.signals import verified, updated

def push_callback(request, push_id):
    if request.method == 'GET':
        mode = request.GET['hub.mode']
        topic = request.GET['hub.topic']
        challenge = request.GET['hub.challenge']
        lease_seconds = request.GET.get('hub.lease_seconds')
        verify_token = request.GET.get('hub.verify_token', '')

        if mode == 'subscribe':
            if not verify_token.startswith('subscribe'):
                raise Http404
            subscription = get_object_or_404(PushSubscription,
                                             pk=push_id,
                                             topic=topic,
                                             verify_token=verify_token)
            subscription.verified = True
            subscription.set_expiration(int(lease_seconds))
            subscription.feed.setup_push()
            verified.send(sender=subscription)

        return HttpResponse(challenge, content_type='text/plain')
    elif request.method == 'POST':
        subscription = get_object_or_404(PushSubscription, pk=push_id)
        parsed = feedparser.parse(request.raw_post_data)
        if parsed.feed.links: # single notification
            hub_url = subscription.hub
            self_url = subscription.topic
            for link in parsed.feed.links:
                if link['rel'] == 'hub':
                    hub_url = link['href']
                elif link['rel'] == 'self':
                    self_url = link['href']

            needs_update = False
            if hub_url and subscription.hub != hub_url:
                # hub URL has changed; let's update our subscription
                needs_update = True
            elif self_url != subscription.topic:
                # topic URL has changed
                needs_update = True

            if needs_update:
                expiration_time = subscription.lease_expires - datetime.now()
                seconds = expiration_time.days*86400 + expiration_time.seconds
                PushSubscription.objects.subscribe(
                    self_url, feed=subscription.feed, hub=hub_url,
                    callback=request.build_absolute_uri(),
                    lease_seconds=seconds)

            # subscription.feed.queue_pushed_feed_xml(request.raw_post_data)
            # Don't give fat ping, just fetch.
            subscription.feed.queue_pushed_feed_xml("Fetch me")

            updated.send(sender=subscription, update=parsed)
            return HttpResponse('')
    return Http404
