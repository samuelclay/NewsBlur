import os
from unittest.mock import patch

from django.test import SimpleTestCase

from utils.prometheus_middleware import (
    PrometheusBeforeMiddleware,
    PrometheusBeforeMiddlewareWrapper,
)


class Test_PrometheusMiddleware(SimpleTestCase):
    @patch.object(PrometheusBeforeMiddleware, "__call__", return_value="response")
    @patch("utils.prometheus_middleware.os.unlink")
    @patch(
        "utils.prometheus_middleware.os.listdir",
        return_value=["counter_123.db", "histogram_123.db"],
    )
    def test_requests_preserve_dead_worker_counter_files(
        self,
        mock_listdir,
        mock_unlink,
        mock_prometheus_call,
    ):
        middleware = PrometheusBeforeMiddlewareWrapper(lambda request: "response")

        with patch.dict(os.environ, {"PROMETHEUS_MULTIPROC_DIR": "/srv/newsblur/.prom_cache"}):
            response = middleware(object())

        self.assertEqual(response, "response")
        mock_listdir.assert_not_called()
        mock_unlink.assert_not_called()
