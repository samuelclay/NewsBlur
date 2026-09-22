"""Tests for the Retry-After header on the per-IP rate limiter's 429.

IPRateTrackingMiddleware in apps/profile/middleware.py blocks an IP for the rest of the
current 5-minute window once it passes the threshold. The 429 it returns should say how
long that window has left. apps/profile/test_ip_rate_limit.py
"""

import datetime
from unittest.mock import patch

from django.contrib.auth.models import AnonymousUser
from django.http import HttpResponse
from django.test import RequestFactory, SimpleTestCase, override_settings

from apps.profile.middleware import IPRateTrackingMiddleware
from utils.ip_rate_tracker import IPRateTracker


class Test_IPRateTrackerWindow(SimpleTestCase):
    def test_seconds_until_next_window_counts_to_the_five_minute_boundary(self):
        tracker = IPRateTracker()
        # 14:32:10 sits 130 seconds into the 14:30 window, leaving 170 seconds.
        self.assertEqual(tracker.seconds_until_next_window(datetime.datetime(2026, 9, 22, 14, 32, 10)), 170)
        # Exactly on a boundary the whole window is still ahead.
        self.assertEqual(tracker.seconds_until_next_window(datetime.datetime(2026, 9, 22, 14, 35, 0)), 300)


@override_settings(IP_RATE_LIMITING_ENABLED=True)
class Test_IPRateLimitRetryAfter(SimpleTestCase):
    def test_blocked_request_carries_retry_after(self):
        middleware = IPRateTrackingMiddleware(lambda request: HttpResponse("ok"))
        request = RequestFactory().get("/reader/feeds", REMOTE_ADDR="203.0.113.7")
        request.user = AnonymousUser()
        with patch.object(IPRateTracker, "track_request"), patch.object(
            IPRateTracker, "track_would_be_denied"
        ), patch.object(IPRateTracker, "is_rate_limited", return_value=True), patch.object(
            IPRateTracker, "seconds_until_next_window", return_value=170
        ):
            response = middleware(request)
        self.assertEqual(response.status_code, 429)
        self.assertEqual(response["Retry-After"], "170")
