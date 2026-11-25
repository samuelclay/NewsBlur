from datetime import timedelta
from unittest.mock import patch

import redis
from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase, override_settings
from django.utils import timezone
from oauth2_provider.models import AccessToken, Application
from prometheus_client.parser import text_string_to_metric_families

from apps.oauth import traffic


@override_settings(OAUTH_METRICS_TOKEN="test-scraper")
class Test_OAuthUsage(TestCase):
    def test_only_authenticated_bearer_requests_count_for_their_application(self):
        user = User.objects.create_user("oauth-metrics")
        user.profile.is_pro = user.profile.is_premium = True
        user.profile.is_premium_trial = False
        user.profile.save(update_fields=["is_premium", "is_pro", "is_premium_trial"])
        app = Application.objects.create(name='A "reader"', user=user)
        token = AccessToken.objects.create(
            application=app, user=user, token="metrics-test", expires=timezone.now() + timedelta(hours=1)
        )
        with patch.object(traffic, "REQUESTS_KEY", "test:oauth:requests"), patch.object(
            traffic, "LAST_USED_KEY", "test:oauth:last_used"
        ):
            connection = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
            keys = [
                traffic.REQUESTS_KEY,
                traffic.LAST_USED_KEY,
                traffic.readers_key(app.pk, int(traffic.time.time()) // 86400),
            ]
            connection.delete(*keys)
            self.addCleanup(connection.delete, *keys)
            self.client.get("/oauth/user/info", HTTP_AUTHORIZATION="Bearer wrong")
            self.client.get("/oauth/user/info", HTTP_AUTHORIZATION="Bearer " + token.token)
            self.client.get("/oauth/user/info", HTTP_AUTHORIZATION="Bearer " + token.token)
            self.client.force_login(user)
            self.client.get("/oauth/user/info")
            self.assertEqual(self.client.get("/monitor/oauth-usage").status_code, 403)
            response = self.client.get("/monitor/oauth-usage", HTTP_AUTHORIZATION="OAuthMetrics test-scraper")
            samples = [
                s
                for family in text_string_to_metric_families(response.content.decode())
                for s in family.samples
            ]
            app_samples = {s.name: s for s in samples if s.labels.get("app_id") == str(app.pk)}
            counted = app_samples["newsblur_oauth_requests_total"]
            self.assertEqual(app_samples["newsblur_oauth_readers_week"].value, 1)
            self.assertEqual(counted.labels["app_name"], app.name)
            self.assertEqual(counted.value, 2)
            self.assertEqual(next(s.value for s in samples if s.name.endswith("active_24h")), 1)
            self.assertGreaterEqual(next(s.value for s in samples if s.name.endswith("created_24h")), 1)
