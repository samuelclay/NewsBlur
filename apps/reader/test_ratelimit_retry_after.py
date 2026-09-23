"""Tests for the Retry-After header on rate-limited 429s and the saved stories cap.

The ratelimit decorator in utils/ratelimit.py counts requests in one-minute buckets and
refuses a request once the buckets in its window add up to the limit. A refused client
needs to know how long the window takes to free up, which is what Retry-After carries.
apps/reader/test_ratelimit_retry_after.py
"""

import datetime
import itertools
from unittest.mock import patch

from django.core.cache import cache
from django.http import HttpResponse
from django.test import RequestFactory, SimpleTestCase, override_settings

from apps.reader import views
from utils.ratelimit import ratelimit, ratelimit_by_url_user

LOCMEM_CACHE = {
    "default": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
        "LOCATION": "ratelimit-retry-after-tests",
    }
}


class FakeSession:
    """Stands in for request.session so the limiter keys on a stable session id."""

    session_key = "test-session"


@override_settings(CACHES=LOCMEM_CACHE, DEBUG=False)
class Test_RatelimitRetryAfter(SimpleTestCase):
    def setUp(self):
        cache.clear()
        self.factory = RequestFactory()

    def make_request(self, path="/reader/starred_stories"):
        request = self.factory.get(path)
        request.session = FakeSession()
        return request

    def decorated_view(self, **options):
        @ratelimit(**options)
        def view(request):
            return HttpResponse("ok")

        return view

    def test_burst_in_one_minute_waits_for_that_minute_to_leave_the_window(self):
        frozen = datetime.datetime(2026, 9, 22, 14, 30, 15)
        view = self.decorated_view(minutes=5, requests=3)
        with patch("utils.ratelimit.datetime") as mock_datetime:
            mock_datetime.now.return_value = frozen
            for _ in range(3):
                self.assertEqual(view(self.make_request()).status_code, 200)
            response = view(self.make_request())
        self.assertEqual(response.status_code, 429)
        # Every hit landed in the 14:30 bucket, which stays inside the six-bucket window
        # until 14:36:00, so the client has to wait five minutes plus the rest of this minute.
        self.assertEqual(response["Retry-After"], str(5 * 60 + 45))

    def test_retry_after_matches_the_buckets_when_the_clock_ticks_mid_request(self):
        before = datetime.datetime(2026, 9, 22, 14, 30, 59)
        after = datetime.datetime(2026, 9, 22, 14, 31, 0)
        view = self.decorated_view(minutes=5, requests=3)
        with patch("utils.ratelimit.datetime") as mock_datetime:
            mock_datetime.now.return_value = before
            for _ in range(3):
                self.assertEqual(view(self.make_request()).status_code, 200)
            # The refused request sees 14:30:59 on its first clock read and 14:31:00 on any
            # later one. The buckets and the wait must come from the same read.
            mock_datetime.now.side_effect = itertools.chain([before], itertools.repeat(after))
            response = view(self.make_request())
        self.assertEqual(response.status_code, 429)
        self.assertEqual(cache.get("rl-test-session-202609221430"), 3)
        # Seen from 14:30:59, the 14:30 bucket leaves the window at 14:36:00: 301 seconds. A
        # window built at 14:30:59 but timed from 14:31:00 would say 360, and buckets built
        # at 14:31:00 would say 300.
        self.assertEqual(response["Retry-After"], "301")

    def test_refused_requests_do_not_extend_the_block(self):
        frozen = datetime.datetime(2026, 9, 22, 14, 30, 15)
        view = self.decorated_view(minutes=1, requests=3)
        with patch("utils.ratelimit.datetime") as mock_datetime:
            mock_datetime.now.return_value = frozen
            for _ in range(3):
                self.assertEqual(view(self.make_request()).status_code, 200)
            for _ in range(5):
                response = view(self.make_request())
                self.assertEqual(response.status_code, 429)
                # The 14:30 bucket stays in the two-bucket window until 14:32:00.
                self.assertEqual(response["Retry-After"], str(60 + 45))
        # A client that ignores Retry-After and keeps polling is refused, but the bucket stays
        # at the three requests that were served, so the header stays truthful.
        self.assertEqual(cache.get("rl-test-session-202609221430"), 3)

    def test_old_bucket_aging_out_gives_a_short_retry_after(self):
        frozen = datetime.datetime(2026, 9, 22, 14, 30, 15)
        view = self.decorated_view(minutes=5, requests=10)
        # Six requests five minutes ago plus four this minute reach the limit of ten.
        # Once the 14:25 bucket ages out at 14:31:00 the window drops back under the limit.
        cache.set("rl-test-session-202609221425", 6, 600)
        cache.set("rl-test-session-202609221430", 4, 600)
        with patch("utils.ratelimit.datetime") as mock_datetime:
            mock_datetime.now.return_value = frozen
            response = view(self.make_request())
        self.assertEqual(response.status_code, 429)
        self.assertEqual(response["Retry-After"], "45")

    def test_two_old_buckets_must_age_out(self):
        frozen = datetime.datetime(2026, 9, 22, 14, 30, 15)
        view = self.decorated_view(minutes=5, requests=7)
        # 14:25 (3) leaves the window at 14:31:00 but 4 + 3 still hits the limit of seven;
        # only once 14:26 (3) leaves at 14:32:00 does the window drop under it.
        cache.set("rl-test-session-202609221425", 3, 600)
        cache.set("rl-test-session-202609221426", 3, 600)
        cache.set("rl-test-session-202609221430", 4, 600)
        with patch("utils.ratelimit.datetime") as mock_datetime:
            mock_datetime.now.return_value = frozen
            response = view(self.make_request())
        self.assertEqual(response.status_code, 429)
        self.assertEqual(response["Retry-After"], str(60 + 45))

    def test_retrying_after_the_header_says_to_is_allowed(self):
        frozen = datetime.datetime(2026, 9, 22, 14, 30, 15)
        view = self.decorated_view(minutes=5, requests=7)
        cache.set("rl-test-session-202609221425", 3, 600)
        cache.set("rl-test-session-202609221426", 3, 600)
        cache.set("rl-test-session-202609221430", 4, 600)
        with patch("utils.ratelimit.datetime") as mock_datetime:
            mock_datetime.now.return_value = frozen
            refused = view(self.make_request())
            self.assertEqual(refused.status_code, 429)
            wait = int(refused["Retry-After"])
            # One second early is still refused, exactly on time is served. This is the
            # property a client that honors the header depends on.
            mock_datetime.now.return_value = frozen + datetime.timedelta(seconds=wait - 1)
            self.assertEqual(view(self.make_request()).status_code, 429)
            mock_datetime.now.return_value = frozen + datetime.timedelta(seconds=wait)
            self.assertEqual(view(self.make_request()).status_code, 200)

    def test_refusal_is_logged_once_per_minute_with_the_path_and_the_wait(self):
        frozen = datetime.datetime(2026, 9, 22, 14, 30, 15)
        view = self.decorated_view(minutes=1, requests=1)
        with patch("utils.ratelimit.datetime") as mock_datetime, patch("utils.ratelimit.logging.user") as log:
            mock_datetime.now.return_value = frozen
            self.assertEqual(view(self.make_request()).status_code, 200)
            for _ in range(5):
                response = view(self.make_request())
                self.assertEqual(response.status_code, 429)
            # A refused request never reaches the view and is not counted, so the log line is
            # the only server-side trace of the block. Five refusals in one minute write one
            # line, and it names the path and the wait.
            log.assert_called_once()
            message = log.call_args.args[1]
            self.assertIn("/reader/starred_stories", message)
            self.assertIn(response["Retry-After"], message)
            # The next minute is still inside the window, so the block continues and is logged
            # again, once, however many times the client polls.
            mock_datetime.now.return_value = frozen + datetime.timedelta(minutes=1)
            for _ in range(3):
                self.assertEqual(view(self.make_request()).status_code, 429)
            self.assertEqual(log.call_count, 2)

    def test_refusal_log_masks_the_url_token(self):
        # folder_rss_feed is limited by ratelimit_by_url_user and its URL carries the account's
        # secret token, which autologin accepts. The refusal log must show the route, not the token.
        @ratelimit_by_url_user(minutes=1, requests=1)
        def view(request):
            return HttpResponse("ok")

        path = "/reader/folder_rss/42/s3cr3ttok3n/unread/folder-name/"
        with patch("utils.ratelimit.logging.user") as log:
            self.assertEqual(view(self.make_request(path)).status_code, 200)
            response = view(self.make_request(path))
        self.assertEqual(response.status_code, 429)
        log.assert_called_once()
        message = log.call_args.args[1]
        self.assertNotIn("s3cr3ttok3n", message)
        self.assertIn("/reader/folder_rss/42/<token>/unread/folder-name", message)
        self.assertIn(response["Retry-After"], message)

    def test_allowed_request_has_no_retry_after(self):
        view = self.decorated_view(minutes=1, requests=5)
        response = view(self.make_request())
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.has_header("Retry-After"))


class Test_StarredStoriesRateLimit(SimpleTestCase):
    def test_saved_stories_allow_100_requests_per_5_minutes(self):
        # A client paging through a saved stories library 10 at a time makes one request per
        # page, so the cap has to fit a full pass over a few hundred saved stories (forum #13844).
        limiter = views.load_starred_stories.ratelimit
        self.assertEqual((limiter.minutes, limiter.requests, limiter.use_path), (5, 100, True))
