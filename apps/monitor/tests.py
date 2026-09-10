from unittest.mock import patch

from django.test import TestCase
from django.test.client import Client

from apps.statistics.rscrapingbee import RScrapingBee


class Test_ScrapingBeeMonitor(TestCase):
    """The /monitor/scrapingbee-usage Prometheus endpoint in apps/monitor/views/newsblur_scrapingbee.py."""

    def setUp(self):
        self.client = Client()
        self.r = RScrapingBee._redis()
        self._delete_keys()

    def tearDown(self):
        self._delete_keys()

    def _delete_keys(self):
        for pattern in (
            "sbCalls:*",
            "sbCredits:*",
            "sbDomains:*",
            "sbDomainCredits:*",
            "sbUsage",
        ):
            for key in self.r.scan_iter(match=pattern):
                self.r.delete(key)

    @patch("apps.monitor.views.newsblur_scrapingbee.RScrapingBee.get_account_usage")
    def test_exports_calls_credits_domains_and_account_usage(self, mock_usage):
        mock_usage.return_value = {
            "used": 918881,
            "max": 1020348,
            "remaining": 101467,
            "used_pct": 90.1,
            "concurrency": 1,
            "max_concurrency": 100,
            "renewal": "2026-09-30T10:28:41",
            "days_to_renewal": 20.5,
        }
        RScrapingBee.record("feed", 200, url="https://www.example.com/feed.xml", credits=1)
        RScrapingBee.record("original_story", 500, url="https://news.example.org/story", credits=0)

        response = self.client.get("/monitor/scrapingbee-usage")

        self.assertEqual(response.status_code, 200)
        body = response.content.decode("utf-8")
        self.assertIn('scrapingbee_usage{metric="calls_today",source="feed",status="200"} 1', body)
        self.assertIn(
            'scrapingbee_usage{metric="calls_today",source="original_story",status="500"} 1',
            body,
        )
        self.assertIn('scrapingbee_usage{metric="calls_today_total"} 2', body)
        self.assertIn('scrapingbee_usage{metric="credits_today",source="feed"} 1', body)
        self.assertIn('scrapingbee_usage{metric="credits_today_total"} 1', body)
        self.assertIn('scrapingbee_usage{metric="domain_credits",host="example.com"} 1', body)
        self.assertIn('scrapingbee_usage{metric="domain_requests",host="example.com"} 1', body)
        self.assertIn('scrapingbee_usage{metric="credits_used"} 918881', body)
        self.assertIn('scrapingbee_usage{metric="credits_max"} 1020348', body)
        self.assertIn('scrapingbee_usage{metric="credits_remaining"} 101467', body)
        self.assertIn('scrapingbee_usage{metric="credits_used_pct"} 90.1', body)
        self.assertIn('scrapingbee_usage{metric="days_to_renewal"} 20.5', body)
        self.assertIn('scrapingbee_usage{metric="credits_per_day_remaining"} 4949', body)

    @patch(
        "apps.monitor.views.newsblur_scrapingbee.RScrapingBee.get_account_usage",
        return_value={},
    )
    def test_renders_without_account_usage(self, mock_usage):
        response = self.client.get("/monitor/scrapingbee-usage")

        self.assertEqual(response.status_code, 200)
        body = response.content.decode("utf-8")
        self.assertIn('scrapingbee_usage{metric="calls_today_total"} 0', body)
        self.assertNotIn('metric="credits_used"', body)
