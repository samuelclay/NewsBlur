"""
Prometheus middleware wrapper that handles mmap errors and performs cleanup
"""
import logging
import os
import time

from django_prometheus.middleware import (
    PrometheusAfterMiddleware,
    PrometheusBeforeMiddleware,
)
from prometheus_client import values

logger = logging.getLogger(__name__)


class PrometheusBeforeMiddlewareWrapper(PrometheusBeforeMiddleware):
    """Wrapper for PrometheusBeforeMiddleware that handles mmap errors"""

    _last_cleanup = 0
    _cleanup_interval = 300  # 5 minutes

    def __call__(self, request):
        try:
            # Periodic cleanup of old files
            current_time = time.time()
            if current_time - self._last_cleanup > self._cleanup_interval:
                self._cleanup_old_files()
                PrometheusBeforeMiddlewareWrapper._last_cleanup = current_time

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

    def _cleanup_old_files(self):
        """Clean up old prometheus files from dead processes"""
        prom_dir = os.environ.get("PROMETHEUS_MULTIPROC_DIR", "/srv/newsblur/.prom_cache")
        if not os.path.exists(prom_dir):
            return

        cleaned = 0
        current_time = time.time()

        try:
            for filename in os.listdir(prom_dir):
                if not filename.endswith(".db"):
                    continue

                filepath = os.path.join(prom_dir, filename)
                # Check if file is older than 1 hour
                if current_time - os.path.getmtime(filepath) > 3600:
                    # Extract PID from filename (e.g., counter_12345.db)
                    parts = filename.split("_")
                    if len(parts) >= 2:
                        try:
                            pid = int(parts[1].replace(".db", ""))
                            # Check if process exists
                            os.kill(pid, 0)
                            # Process exists, skip
                            continue
                        except (ValueError, OSError):
                            # Process doesn't exist, safe to delete
                            pass

                    try:
                        os.unlink(filepath)
                        cleaned += 1
                    except Exception as e:
                        logger.debug(f"Could not remove {filepath}: {e}")

            if cleaned > 0:
                logger.info(f"Cleaned up {cleaned} old prometheus files")

        except Exception as e:
            logger.error(f"Error during prometheus cleanup: {e}")

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
