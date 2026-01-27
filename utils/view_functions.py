import functools
import json as json_lib
import time

import redis
from django.conf import settings
from django.http import Http404, HttpResponse
from django.shortcuts import render

from utils import json_functions as json
from utils import log as logging


class RequestDeduplicator:
    """
    Deduplicates concurrent identical requests by having duplicate requests wait
    for and share the result of the first request.

    Usage:
        deduper = RequestDeduplicator(request, cache_key)
        cached = deduper.check_for_duplicate()
        if cached is not None:
            return cached
        # ... do expensive work ...
        deduper.cache_result(data)
        return data

    Only the first request for a given cache_key will process; concurrent duplicates
    wait for the result. Results are cached briefly (default 5 seconds) just long
    enough for waiting duplicates to pick them up.
    """

    def __init__(self, request, cache_key, wait_timeout=30, cache_ttl=5, in_progress_ttl=45):
        """
        Args:
            request: Django request object (for logging)
            cache_key: Unique key identifying this request's parameters
            wait_timeout: How long duplicate requests wait for result (seconds)
            cache_ttl: How long to cache the result (seconds)
            in_progress_ttl: TTL for in_progress marker as safety (seconds)
        """
        self.request = request
        self.cache_key = cache_key
        self.in_progress_key = f"{cache_key}:in_progress"
        self.wait_timeout = wait_timeout
        self.cache_ttl = cache_ttl
        self.in_progress_ttl = in_progress_ttl
        self.is_primary = False  # True if this request is processing (not waiting)
        self._redis = None

    @property
    def r(self):
        if self._redis is None:
            self._redis = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        return self._redis

    def check_for_duplicate(self):
        """
        Check if another identical request is in progress.

        Returns:
            - Cached result dict if a duplicate was deduplicated
            - None if this request should proceed with processing
        """
        if self.r.exists(self.in_progress_key):
            # Another identical request is in flight - wait for its result
            iterations = int(self.wait_timeout * 10)  # 100ms per iteration
            for _ in range(iterations):
                time.sleep(0.1)
                cached_result = self.r.get(self.cache_key)
                if cached_result:
                    logging.user(self.request, "~FC~BBDeduped request (waited for in-flight)")
                    return json_lib.loads(cached_result)
                # Check if in_progress cleared but no result (request failed)
                if not self.r.exists(self.in_progress_key):
                    break
            # Other request finished without caching or timed out - proceed normally
            return None
        else:
            # First request for this key - mark as in progress
            self.r.setex(self.in_progress_key, self.in_progress_ttl, "1")
            self.is_primary = True
            return None

    def cache_result(self, data):
        """
        Cache the result briefly for any waiting duplicate requests.
        Call this after processing completes successfully.
        """
        if self.is_primary:
            try:
                self.r.setex(self.cache_key, self.cache_ttl, json_lib.dumps(data, default=str))
            except Exception as e:
                logging.user(self.request, f"~FRFailed to cache dedupe result: {e}")
            finally:
                self.r.delete(self.in_progress_key)

    def clear(self):
        """Clear the in_progress marker without caching (e.g., on error)."""
        if self.is_primary:
            self.r.delete(self.in_progress_key)


def get_argument_or_404(request, param, method="POST", code="404"):
    try:
        return getattr(request, method)[param]
    except KeyError:
        if code == "404":
            raise Http404
        else:
            return


def render_to(template):
    """
    Decorator for Django views that sends returned dict to render function.

    If view doesn't return dict then decorator simply returns output.
    Additionally view can return two-tuple, which must contain dict as first
    element and string with template name as second. This string will
    override template name, given as parameter

    Parameters:

     - template: template name to use
    """

    def renderer(func):
        def wrapper(request, *args, **kw):
            output = func(request, *args, **kw)
            if isinstance(output, (list, tuple)):
                return render(request, output[1], output[0])
            elif isinstance(output, dict):
                return render(request, template, output)
            return output

        return wrapper

    return renderer


def is_true(value):
    if value == 1:
        return True
    return bool(value) and isinstance(value, str) and value.lower() not in ("false", "0")


class required_params(object):
    "Instances of this class can be used as decorators"

    def __init__(self, *args, **kwargs):
        self.params = args
        self.named_params = kwargs
        self.method = kwargs.get("method", "POST")

    def __call__(self, fn):
        def wrapper(request, *args, **kwargs):
            return self.view_wrapper(request, fn, *args, **kwargs)

        functools.update_wrapper(wrapper, fn)
        return wrapper

    def view_wrapper(self, request, fn, *args, **kwargs):
        if request.method != self.method and self.method != "REQUEST":
            return self.disallowed(method=True, status_code=405)

        # Check if parameter is included
        for param in self.params:
            if getattr(request, self.method).get(param) is None:
                print(" Unnamed parameter not found: %s" % param)
                return self.disallowed(param)

        # Check if parameter is correct type
        for param, param_type in list(self.named_params.items()):
            if param == "method":
                continue
            if getattr(request, self.method).get(param) is None:
                print(" Typed parameter not found: %s" % param)
                return self.disallowed(param)
            try:
                if param_type(getattr(request, self.method).get(param)) is None:
                    print(" Typed parameter wrong: %s" % param)
                    return self.disallowed(param, param_type)
            except (TypeError, ValueError) as e:
                print(" %s -> %s" % (param, e))
                return self.disallowed(param, param_type)

        return fn(request, *args, **kwargs)

    def disallowed(self, param=None, param_type=None, method=False, status_code=400):
        if method:
            message = "Invalid HTTP method. Use %s." % self.method
        elif param_type:
            message = "Invalid paramter: %s - needs to be %s" % (
                param,
                param_type,
            )
        else:
            message = "Missing parameter: %s" % param

        return HttpResponse(
            json.encode(
                {
                    "message": message,
                    "code": -1,
                }
            ),
            content_type="application/json",
            status=status_code,
        )
