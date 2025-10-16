# Copyright 2009 - Participatory Culture Foundation
#
# This file is part of djpubsubhubbub.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import urllib
from datetime import datetime, timedelta

from django.test import TestCase
from django.urls import reverse

from apps.push.models import PushSubscription, PushSubscriptionManager
from apps.push.signals import pre_subscribe, updated, verified
from apps.rss_feeds.models import Feed


class MockResponse(object):
    def __init__(self, status, data=None):
        self.status = status
        self.status_code = status  # Add status_code for compatibility
        self.data = data
        self.text = data or ""  # Add text attribute for error handling

    def info(self):
        return self

    def read(self):
        if self.data is None:
            return ""
        data, self.data = self.data, None
        return data


class PSHBTestBase:
    urls = "apps.push.urls"

    def create_feed_and_subscription(self, topic="topic", hub="hub", verified=False, **kwargs):
        """Helper to create a Feed and PushSubscription for testing."""
        feed = Feed.objects.create(feed_link=topic, feed_title="Test Feed for %s" % topic)
        sub = PushSubscription.objects.create(feed=feed, topic=topic, hub=hub, verified=verified, **kwargs)
        return sub

    def setUp(self):
        self._old_send_request = PushSubscriptionManager._send_request
        PushSubscriptionManager._send_request = self._send_request
        self.responses = []
        self.requests = []
        self.signals = []
        for connecter in pre_subscribe, verified, updated:

            def callback(signal=None, **kwargs):
                self.signals.append((signal, kwargs))

            connecter.connect(callback, dispatch_uid=connecter, weak=False)

    def tearDown(self):
        PushSubscriptionManager._send_request = self._old_send_request
        del self._old_send_request
        for signal in pre_subscribe, verified:
            signal.disconnect(dispatch_uid=signal)

    def _send_request(self, url, data):
        self.requests.append((url, data))
        return self.responses.pop()


class Test_PSHBSubscriptionManagerTest(PSHBTestBase, TestCase):
    def test_sync_verify(self):
        """
        If the hub returns a 204 response, the subscription is verified and
        active.
        """
        self.responses.append(MockResponse(204))
        feed = Feed.objects.create(
            feed_link="topic", feed_title="Test Feed", hash_address_and_link="test_sync_verify"
        )
        sub = PushSubscription.objects.subscribe(
            "topic", feed, hub="hub", callback="callback", lease_seconds=2000
        )
        self.assertEquals(len(self.signals), 2)
        self.assertEquals(self.signals[0], (pre_subscribe, {"sender": sub, "created": True}))
        self.assertEquals(self.signals[1], (verified, {"sender": sub}))
        self.assertEquals(sub.hub, "hub")
        self.assertEquals(sub.topic, "topic")
        self.assertEquals(sub.verified, True)
        rough_expires = datetime.now() + timedelta(seconds=2000)
        self.assert_(abs(sub.lease_expires - rough_expires).seconds < 5, "lease more than 5 seconds off")
        self.assertEquals(len(self.requests), 1)
        request = self.requests[0]
        self.assertEquals(request[0], "hub")
        self.assertEquals(request[1]["hub.mode"], "subscribe")
        self.assertEquals(request[1]["hub.topic"], "topic")
        self.assertEquals(request[1]["hub.callback"], "callback")
        self.assertEquals(request[1]["hub.verify"], ["async", "sync"])
        self.assertEquals(request[1]["hub.verify_token"], sub.verify_token)
        self.assertEquals(request[1]["hub.lease_seconds"], 2000)

    def test_async_verify(self):
        """
        If the hub returns a 202 response, we should not assume the
        subscription is verified.
        """
        self.responses.append(MockResponse(202))
        feed = Feed.objects.create(
            feed_link="topic", feed_title="Test Feed", hash_address_and_link="test_async_verify"
        )
        sub = PushSubscription.objects.subscribe(
            "topic", feed, hub="hub", callback="callback", lease_seconds=2000
        )
        self.assertEquals(len(self.signals), 1)
        self.assertEquals(self.signals[0], (pre_subscribe, {"sender": sub, "created": True}))
        self.assertEquals(sub.hub, "hub")
        self.assertEquals(sub.topic, "topic")
        self.assertEquals(sub.verified, False)
        rough_expires = datetime.now() + timedelta(seconds=2000)
        self.assert_(abs(sub.lease_expires - rough_expires).seconds < 5, "lease more than 5 seconds off")
        self.assertEquals(len(self.requests), 1)
        request = self.requests[0]
        self.assertEquals(request[0], "hub")
        self.assertEquals(request[1]["hub.mode"], "subscribe")
        self.assertEquals(request[1]["hub.topic"], "topic")
        self.assertEquals(request[1]["hub.callback"], "callback")
        self.assertEquals(request[1]["hub.verify"], ["async", "sync"])
        self.assertEquals(request[1]["hub.verify_token"], sub.verify_token)
        self.assertEquals(request[1]["hub.lease_seconds"], 2000)

    def test_least_seconds_default(self):
        """
        If the number of seconds to lease the subscription is not specified, it
        should default to 864000 (10 days).
        """
        self.responses.append(MockResponse(202))
        feed = Feed.objects.create(
            feed_link="topic", feed_title="Test Feed", hash_address_and_link="test_lease_seconds"
        )
        sub = PushSubscription.objects.subscribe("topic", feed, hub="hub", callback="callback")
        rough_expires = datetime.now() + timedelta(seconds=864000)
        self.assert_(abs(sub.lease_expires - rough_expires).seconds < 5, "lease more than 5 seconds off")
        self.assertEquals(len(self.requests), 1)
        request = self.requests[0]
        self.assertEquals(request[1]["hub.lease_seconds"], 864000)

    def test_error_on_subscribe_raises_URLError(self):
        """
        If a non-202/204 status is returned, raise a URLError.
        """
        self.responses.append(MockResponse(500, "error data"))
        feed = Feed.objects.create(
            feed_link="topic", feed_title="Test Feed", hash_address_and_link="test_error_subscribe"
        )
        try:
            PushSubscription.objects.subscribe("topic", feed, hub="hub", callback="callback")
        except urllib.error.URLError as e:
            self.assertEquals(e.reason, "error subscribing to topic on hub:\nerror data")
        else:
            self.fail("subscription did not raise URLError exception")


class Test_PSHBCallbackViewCase(PSHBTestBase, TestCase):
    def test_verify(self):
        """
        Getting the callback from the server should verify the subscription.
        """
        sub = self.create_feed_and_subscription(topic="topic", hub="hub", verified=False)
        verify_token = sub.generate_token("subscribe")

        response = self.client.get(
            reverse("push-callback", args=(sub.pk,)),
            {
                "hub.mode": "subscribe",
                "hub.topic": sub.topic,
                "hub.challenge": "challenge",
                "hub.lease_seconds": 2000,
                "hub.verify_token": verify_token,
            },
        )

        self.assertEquals(response.status_code, 200)
        self.assertEquals(response.content, b"challenge")
        sub = PushSubscription.objects.get(pk=sub.pk)
        self.assertEquals(sub.verified, True)
        self.assertEquals(len(self.signals), 1)
        self.assertEquals(self.signals[0], (verified, {"sender": sub}))

    def test_404(self):
        """
        Various things sould return a 404:

        * invalid primary key in the URL
        * token doesn't start with 'subscribe'
        * subscription doesn't exist
        * token doesn't match the subscription
        """
        import logging

        # Suppress expected 404 warnings in this test
        logging.disable(logging.WARNING)
        try:
            sub = self.create_feed_and_subscription(topic="topic", hub="hub", verified=False)
            verify_token = sub.generate_token("subscribe")

            response = self.client.get(
                reverse("push-callback", args=(0,)),
                {
                    "hub.mode": "subscribe",
                    "hub.topic": sub.topic,
                    "hub.challenge": "challenge",
                    "hub.lease_seconds": 2000,
                    "hub.verify_token": verify_token[1:],
                },
            )
            self.assertEquals(response.status_code, 404)
            self.assertEquals(len(self.signals), 0)

            response = self.client.get(
                reverse("push-callback", args=(sub.pk,)),
                {
                    "hub.mode": "subscribe",
                    "hub.topic": sub.topic,
                    "hub.challenge": "challenge",
                    "hub.lease_seconds": 2000,
                    "hub.verify_token": verify_token[1:],
                },
            )
            self.assertEquals(response.status_code, 404)
            self.assertEquals(len(self.signals), 0)

            response = self.client.get(
                reverse("push-callback", args=(sub.pk,)),
                {
                    "hub.mode": "subscribe",
                    "hub.topic": sub.topic + "extra",
                    "hub.challenge": "challenge",
                    "hub.lease_seconds": 2000,
                    "hub.verify_token": verify_token,
                },
            )
            self.assertEquals(response.status_code, 404)
            self.assertEquals(len(self.signals), 0)

            response = self.client.get(
                reverse("push-callback", args=(sub.pk,)),
                {
                    "hub.mode": "subscribe",
                    "hub.topic": sub.topic,
                    "hub.challenge": "challenge",
                    "hub.lease_seconds": 2000,
                    "hub.verify_token": verify_token[:-5],
                },
            )
            self.assertEquals(response.status_code, 404)
            self.assertEquals(len(self.signals), 0)
        finally:
            # Re-enable logging after test
            logging.disable(logging.NOTSET)


class Test_PSHBUpdateCase(PSHBTestBase, TestCase):
    def test_update(self):
        # this data comes from
        # http://pubsubhubbub.googlecode.com/svn/trunk/pubsubhubbub-core-0.1.html#anchor3
        update_data = """<?xml version="1.0"?>
<atom:feed>
  <!-- Normally here would be source, title, etc ... -->

  <link rel="hub" href="http://myhub.example.com/endpoint" />
  <link rel="self" href="http://publisher.example.com/happycats.xml" />
  <updated>2008-08-11T02:15:01Z</updated>

  <!-- Example of a full entry. -->
  <entry>
    <title>Heathcliff</title>
    <link href="http://publisher.example.com/happycat25.xml" />
    <id>http://publisher.example.com/happycat25.xml</id>
    <updated>2008-08-11T02:15:01Z</updated>
    <content>
      What a happy cat. Full content goes here.
    </content>
  </entry>

  <!-- Example of an entity that isn't full/is truncated. This is implied
       by the lack of a <content> element and a <summary> element instead. -->
  <entry >
    <title>Heathcliff</title>
    <link href="http://publisher.example.com/happycat25.xml" />
    <id>http://publisher.example.com/happycat25.xml</id>
    <updated>2008-08-11T02:15:01Z</updated>
    <summary>
      What a happy cat!
    </summary>
  </entry>

  <!-- Meta-data only; implied by the lack of <content> and
       <summary> elements. -->
  <entry>
    <title>Garfield</title>
    <link rel="alternate" href="http://publisher.example.com/happycat24.xml" />
    <id>http://publisher.example.com/happycat25.xml</id>
    <updated>2008-08-11T02:15:01Z</updated>
  </entry>

  <!-- Context entry that's meta-data only and not new. Implied because the
       update time on this entry is before the //atom:feed/updated time. -->
  <entry>
    <title>Nermal</title>
    <link rel="alternate" href="http://publisher.example.com/happycat23s.xml" />
    <id>http://publisher.example.com/happycat25.xml</id>
    <updated>2008-07-10T12:28:13Z</updated>
  </entry>

</atom:feed>
"""

        # Create a feed first since PushSubscription requires it
        feed = Feed.objects.create(
            feed_link="http://publisher.example.com/happycats.xml", feed_title="Happy Cats Test Feed"
        )
        sub = PushSubscription.objects.create(
            feed=feed,
            hub="http://myhub.example.com/endpoint",
            topic="http://publisher.example.com/happycats.xml",
        )

        # The current implementation doesn't parse or send update signals
        # It just queues a feed fetch
        response = self.client.post(
            reverse("push-callback", args=(sub.pk,)), update_data, "application/atom+xml"
        )
        self.assertEquals(response.status_code, 200)
        self.assertEquals(response.content, b"OK")

    def test_update_with_changed_hub(self):
        update_data = """<?xml version="1.0"?>
<atom:feed>
  <!-- Normally here would be source, title, etc ... -->

  <link rel="hub" href="http://myhub.example.com/endpoint" />
  <link rel="self" href="http://publisher.example.com/happycats.xml" />
  <updated>2008-08-11T02:15:01Z</updated>

  <entry>
    <title>Heathcliff</title>
    <link href="http://publisher.example.com/happycat25.xml" />
    <id>http://publisher.example.com/happycat25.xml</id>
    <updated>2008-08-11T02:15:01Z</updated>
    <content>
      What a happy cat. Full content goes here.
    </content>
  </entry>
</atom:feed>
"""
        sub = self.create_feed_and_subscription(
            hub="hub",
            topic="http://publisher.example.com/happycats.xml",
            lease_expires=datetime.now() + timedelta(days=1),
        )

        # Add response for subscription update
        self.responses.append(MockResponse(204))

        # The current implementation doesn't update subscriptions or send signals
        response = self.client.post(
            reverse("push-callback", args=(sub.pk,)), update_data, "application/atom+xml"
        )
        self.assertEquals(response.status_code, 200)
        self.assertEquals(response.content, b"OK")

    def test_update_with_changed_self(self):
        update_data = """<?xml version="1.0"?>
<atom:feed>
  <!-- Normally here would be source, title, etc ... -->

  <link rel="hub" href="http://myhub.example.com/endpoint" />
  <link rel="self" href="http://publisher.example.com/happycats.xml" />
  <updated>2008-08-11T02:15:01Z</updated>

  <entry>
    <title>Heathcliff</title>
    <link href="http://publisher.example.com/happycat25.xml" />
    <id>http://publisher.example.com/happycat25.xml</id>
    <updated>2008-08-11T02:15:01Z</updated>
    <content>
      What a happy cat. Full content goes here.
    </content>
  </entry>
</atom:feed>
"""
        sub = self.create_feed_and_subscription(
            hub="http://myhub.example.com/endpoint",
            topic="topic",
            lease_expires=datetime.now() + timedelta(days=1),
        )

        # Add response for subscription update
        self.responses.append(MockResponse(204))

        # The current implementation doesn't update subscriptions or send signals
        response = self.client.post(
            reverse("push-callback", kwargs={"push_id": sub.pk}), update_data, "application/atom+xml"
        )
        self.assertEquals(response.status_code, 200)
        self.assertEquals(response.content, b"OK")

    def test_update_with_changed_hub_and_self(self):
        update_data = """<?xml version="1.0"?>
<atom:feed>
  <!-- Normally here would be source, title, etc ... -->

  <link rel="hub" href="http://myhub.example.com/endpoint" />
  <link rel="self" href="http://publisher.example.com/happycats.xml" />
  <updated>2008-08-11T02:15:01Z</updated>

  <entry>
    <title>Heathcliff</title>
    <link href="http://publisher.example.com/happycat25.xml" />
    <id>http://publisher.example.com/happycat25.xml</id>
    <updated>2008-08-11T02:15:01Z</updated>
    <content>
      What a happy cat. Full content goes here.
    </content>
  </entry>
</atom:feed>
"""
        sub = self.create_feed_and_subscription(
            hub="hub", topic="topic", lease_expires=datetime.now() + timedelta(days=1)
        )

        # Add response for subscription update
        self.responses.append(MockResponse(204))

        # The current implementation doesn't update subscriptions or send signals
        response = self.client.post(
            reverse("push-callback", args=(sub.pk,)), update_data, "application/atom+xml"
        )
        self.assertEquals(response.status_code, 200)
        self.assertEquals(response.content, b"OK")
