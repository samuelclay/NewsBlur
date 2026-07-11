"""Prometheus middleware wrapper that handles mmap errors and directory setup."""
import logging
import os

from django_prometheus.middleware import PrometheusAfterMiddleware, PrometheusBeforeMiddleware
from prometheus_client import values

logger = logging.getLogger(__name__)


def ensure_prometheus_directory():
    """Ensure the Prometheus multiproc directory exists"""
    prom_dir = os.environ.get("PROMETHEUS_MULTIPROC_DIR", "/srv/newsblur/.prom_cache")
    if not os.path.exists(prom_dir):
        try:
            os.makedirs(prom_dir, mode=0o777, exist_ok=True)
            logger.info(f"Created Prometheus multiproc directory: {prom_dir}")
        except Exception as e:
            logger.error(f"Failed to create Prometheus directory {prom_dir}: {e}")
    return prom_dir


# Ensure directory exists when module is loaded
ensure_prometheus_directory()


class PrometheusBeforeMiddlewareWrapper(PrometheusBeforeMiddleware):
    """Wrapper for PrometheusBeforeMiddleware that handles mmap errors"""

    def __call__(self, request):
        try:
            return super().__call__(request)
        except IndexError as e:
            if "mmap slice assignment is wrong size" in str(e):
                logger.warning("Prometheus mmap corruption detected, attempting recovery")
                self._reset_prometheus_mmap()
                # Try once more after reset
                try:
                    return super().__call__(request)
                except Exception as retry_error:
                    logger.error(f"Prometheus retry failed: {retry_error}")
                    # Continue without metrics rather than crash
                    return self.get_response(request)
            raise

    def _reset_prometheus_mmap(self):
        """Reset prometheus mmap cache when corruption is detected"""
        try:
            # Clear the mmap cache
            if hasattr(values, "_ValueClass") and hasattr(values._ValueClass, "_mmap_dict_cache"):
                values._ValueClass._mmap_dict_cache.clear()
            logger.info("Reset prometheus mmap cache")
        except Exception as e:
            logger.error(f"Error resetting prometheus mmap: {e}")


class PrometheusAfterMiddlewareWrapper(PrometheusAfterMiddleware):
    """Wrapper for PrometheusAfterMiddleware that handles mmap errors"""

    def __call__(self, request):
        try:
            return super().__call__(request)
        except IndexError as e:
            if "mmap slice assignment is wrong size" in str(e):
                logger.warning("Prometheus mmap corruption in after middleware, continuing without metrics")
                # Get the response without metrics
                if hasattr(self, "_response"):
                    return self._response
                return None
            raise

    def process_response(self, request, response):
        # Store response in case we need it during error recovery
        self._response = response
        try:
            return super().process_response(request, response)
        except IndexError as e:
            if "mmap slice assignment is wrong size" in str(e):
                logger.warning("Prometheus mmap corruption in process_response, continuing without metrics")
                return response
            raise
