# Adapted from djpubsubhubbub. See License: http://git.participatoryculture.org/djpubsubhubbub/tree/LICENSE

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
        # XXX TODO: Optimize this by removing feedparser. It just needs to find out
        # the hub_url or topic has changed. ElementTree could do it.
        parsed = feedparser.parse(request.raw_post_data)
        subscription.check_urls_against_pushed_data(parsed)
        updated.send(sender=subscription, update=parsed)

        # Don't give fat ping, just fetch.
        # subscription.feed.queue_pushed_feed_xml(request.raw_post_data)
        subscription.feed.queue_pushed_feed_xml("Fetch me")

        return HttpResponse('')
    return Http404
