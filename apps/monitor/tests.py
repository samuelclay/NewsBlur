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
            "sbUserCredits:*",
            "sbUsersCharged:*",
            "sbUserBudget",
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
        self.assertIn('scrapingbee_usage{metric="user_budget"} ', body)
        self.assertIn('scrapingbee_usage{metric="users_charged_period"} 0', body)
        self.assertIn('scrapingbee_usage{metric="users_over_budget"} 0', body)

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


class Test_LLMCostPricing(TestCase):
    """Model prices in utils/llm_costs.py for the models named in utils/llm_models.py."""

    def test_every_current_model_has_a_price_and_provider(self):
        from utils import llm_models
        from utils.llm_costs import MODEL_PRICING, MODEL_PROVIDERS

        current_models = {
            llm_models.ANTHROPIC_MODEL: "anthropic",
            llm_models.ANTHROPIC_CHAT_MODEL: "anthropic",
            llm_models.ANTHROPIC_ARCHIVE_MODEL: "anthropic",
            llm_models.OPENAI_MODEL: "openai",
            llm_models.GOOGLE_MODEL: "google",
            llm_models.XAI_MODEL: "xai",
        }
        for model, provider in current_models.items():
            self.assertIn(model, MODEL_PRICING, f"{model} has no price, so its usage records $0")
            self.assertEqual(MODEL_PROVIDERS.get(model), provider)

    def test_flat_priced_model(self):
        from utils.llm_costs import LLMCostTracker

        cost = LLMCostTracker.calculate_cost("claude-sonnet-5-5", 1_000_000, 1_000_000)
        self.assertAlmostEqual(cost, 2.00 + 10.00)

    def test_haiku_5_5_short_prompt_uses_base_rates(self):
        from utils.llm_costs import LLMCostTracker

        cost = LLMCostTracker.calculate_cost("claude-haiku-5-5", 100_000, 1_000)
        self.assertAlmostEqual(cost, 100_000 / 1_000_000 * 0.10 + 1_000 / 1_000_000 * 0.50)

    def test_haiku_5_5_long_prompt_bills_whole_request_at_long_context_rates(self):
        from utils.llm_costs import LLMCostTracker

        cost = LLMCostTracker.calculate_cost("claude-haiku-5-5", 100_001, 1_000)
        self.assertAlmostEqual(cost, 100_001 / 1_000_000 * 0.50 + 1_000 / 1_000_000 * 2.50)

    def test_grok_4_7_doubles_at_200k_prompt_tokens(self):
        from utils.llm_costs import LLMCostTracker

        below = LLMCostTracker.calculate_cost("grok-4.7", 199_999, 1_000)
        at_threshold = LLMCostTracker.calculate_cost("grok-4.7", 200_000, 1_000)
        self.assertAlmostEqual(below, 199_999 / 1_000_000 * 2.00 + 1_000 / 1_000_000 * 6.00)
        self.assertAlmostEqual(at_threshold, 200_000 / 1_000_000 * 4.00 + 1_000 / 1_000_000 * 12.00)
