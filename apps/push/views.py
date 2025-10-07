# Adapted from djpubsubhubbub. See License: http://git.participatoryculture.org/djpubsubhubbub/tree/LICENSE

import datetime
import random

import feedparser
from django.http import Http404, HttpResponse
from django.http.request import UnreadablePostError
from django.shortcuts import get_object_or_404

from apps.push.models import PushSubscription
from apps.push.signals import verified
from apps.rss_feeds.models import MFetchHistory
from utils import log as logging


def push_callback(request, push_id):
    if request.method == "GET":
        mode = request.GET["hub.mode"]
        topic = request.GET["hub.topic"]
        challenge = request.GET.get("hub.challenge", "")
        lease_seconds = request.GET.get("hub.lease_seconds")
        verify_token = request.GET.get("hub.verify_token", "")

        if mode == "subscribe":
            if not verify_token.startswith("subscribe"):
                raise Http404
            subscription = get_object_or_404(
                PushSubscription, pk=push_id, topic=topic, verify_token=verify_token
            )
            subscription.verified = True
            subscription.set_expiration(int(lease_seconds))
            subscription.save()
            subscription.feed.setup_push()

            logging.debug("   ---> [%-30s] [%s] ~BBVerified PuSH" % (subscription.feed, subscription.feed_id))

            verified.send(sender=subscription)

        return HttpResponse(challenge, content_type="text/plain")
    elif request.method == "POST":
        subscription = get_object_or_404(PushSubscription, pk=push_id)
        fetch_history = MFetchHistory.feed(subscription.feed_id)
        latest_push_date_delta = None
        if fetch_history and fetch_history.get("push_history"):
            latest_push = fetch_history["push_history"][0]["push_date"]
            latest_push_date = datetime.datetime.strptime(latest_push, "%Y-%m-%d %H:%M:%S")
            latest_push_date_delta = datetime.datetime.now() - latest_push_date
            if latest_push_date > datetime.datetime.now() - datetime.timedelta(minutes=1):
                logging.debug(
                    "   ---> [%-30s] ~SN~FBSkipping feed fetch, pushed %s seconds ago"
                    % (subscription.feed, latest_push_date_delta.seconds)
                )
                return HttpResponse(
                    "Slow down, you just pushed %s seconds ago..." % latest_push_date_delta.seconds,
                    status=429,
                )

        # XXX TODO: Optimize this by removing feedparser. It just needs to find out
        # the hub_url or topic has changed. ElementTree could do it.
        if random.random() < 0.1:
            try:
                parsed = feedparser.parse(request.body)
                subscription.check_urls_against_pushed_data(parsed)
            except UnreadablePostError:
                pass

        # Don't give fat ping, just fetch.
        # subscription.feed.queue_pushed_feed_xml(request.body)
        if subscription.feed.active_subscribers >= 1:
            subscription.feed.queue_pushed_feed_xml("Fetch me", latest_push_date_delta=latest_push_date_delta)
            MFetchHistory.add(feed_id=subscription.feed_id, fetch_type="push")
        else:
            logging.debug(
                "   ---> [%-30s] ~FBSkipping feed fetch, no actives: %s"
                % (subscription.feed, subscription.feed)
            )

        return HttpResponse("OK")
    return Http404
