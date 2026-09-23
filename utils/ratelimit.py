"""Request rate-limiting decorator backed by Django's cache framework.

Provides a configurable class-based decorator that limits the number of
requests per time period, keyed by IP address and optionally request path.
"""

import functools
import hashlib
from datetime import datetime, timedelta

from django.conf import settings
from django.core.cache import cache
from django.http import HttpResponse

from utils import log as logging


class ratelimit(object):
    "Instances of this class can be used as decorators"
    # This class is designed to be sub-classed
    minutes = 1  # The time period
    requests = 4  # Number of allowed requests in that time period
    DEBUG_MULTIPLIER = 10  # In DEBUG mode, multiply request limits by this factor
    use_path = False  # Whether to include the request path in the key

    prefix = "rl-"  # Prefix for memcache key

    def __init__(self, **options):
        for key, value in options.items():
            setattr(self, key, value)

    def __call__(self, fn):
        def wrapper(request, *args, **kwargs):
            return self.view_wrapper(request, fn, *args, **kwargs)

        functools.update_wrapper(wrapper, fn)
        # Expose the limiter on the view so callers and tests can read its window. utils/ratelimit.py
        wrapper.ratelimit = self
        return wrapper

    def view_wrapper(self, request, fn, *args, **kwargs):
        if not self.should_ratelimit(request):
            return fn(request, *args, **kwargs)

        # One clock read for the whole check, so the buckets read, the bucket incremented, and
        # the Retry-After arithmetic all describe the same window. utils/ratelimit.py
        now = datetime.now()
        keys = self.keys_to_check(request, now)
        counters = self.cache_get_many(keys)

        # Have they failed? A refused request is not counted, so Retry-After is the real wait
        # and a client that keeps polling does not stretch its own block.
        if sum(counters.values()) >= self.limit():
            retry_after = self.retry_after(keys, counters, now)
            # A refused request is not counted and never reaches the view, so this line is the
            # only server-side trace of the block. It is written for the first refusal in each
            # minute per key: a client that ignores the header and keeps polling is refused
            # every time but logged once a minute, so the log says who was blocked without
            # growing with the poll rate. utils/ratelimit.py
            if cache.add(keys[0] + "-logged", 1, 60):
                logging.user(
                    request,
                    "~FR~SB429 rate limited~SN ~FR%s retry in %ss" % (self.log_path(request), retry_after),
                )
            return self.disallowed(request, retry_after=retry_after)

        # Increment rate limiting counter for the current minute
        self.cache_incr(keys[0])

        return fn(request, *args, **kwargs)

    def log_path(self, request):
        """The path as it may appear in the refusal log. Subclasses whose URLs carry a secret
        override this to mask it before it reaches the log. utils/ratelimit.py"""
        return request.path

    def limit(self):
        "Allowed requests per window. In DEBUG mode, allow 10x more requests."
        if settings.DEBUG:
            return self.requests * self.DEBUG_MULTIPLIER
        return self.requests

    def retry_after(self, keys, counters, now):
        """Seconds until enough one-minute buckets have aged out of the window for a retry to pass.

        `keys` is the keys_to_check() list for `now`, newest first. The oldest bucket leaves the
        window at the next minute boundary, the next oldest a minute after that, and so on.
        Refused requests are not counted, so the buckets are used as read. utils/ratelimit.py
        """
        counts = [counters.get(key, 0) for key in keys]
        seconds_to_next_minute = 60 - now.second
        limit = self.limit()
        for dropped in range(1, len(counts)):
            if sum(counts[: len(counts) - dropped]) < limit:
                return (dropped - 1) * 60 + seconds_to_next_minute
        # Even the current bucket alone is over the limit, so wait until it leaves the window.
        return (len(counts) - 1) * 60 + seconds_to_next_minute

    def cache_get_many(self, keys):
        return cache.get_many(keys)

    def cache_incr(self, key):
        # memcache is only backend that can increment atomically
        try:
            # add first, to ensure the key exists
            cache.add(key, 0, self.expire_after())
            cache.incr(key)
        except (AttributeError, ValueError):
            cache.set(key, cache.get(key, 0) + 1, self.expire_after())

    def should_ratelimit(self, request):
        return True

    def keys_to_check(self, request, now=None):
        "Bucket keys for the window ending at `now`, newest first. utils/ratelimit.py"
        extra = self.key_extra(request)
        if now is None:
            now = datetime.now()
        return [
            "%s%s-%s" % (self.prefix, extra, (now - timedelta(minutes=minute)).strftime("%Y%m%d%H%M"))
            for minute in range(self.minutes + 1)
        ]

    def key_extra(self, request):
        key = getattr(request.session, "session_key", "")
        if not key:
            key = request.META.get("HTTP_X_FORWARDED_FOR", "").split(",")[0]
        if not key:
            key = request.COOKIES.get("newsblur_sessionid", "")
        if not key:
            key = request.META.get("HTTP_USER_AGENT", "")

        # Add request path to the key if use_path is enabled
        if getattr(self, "use_path", False):
            path = request.path
            key = f"{key}-{path}"

        return key

    def disallowed(self, request, retry_after=None):
        response = HttpResponse("Rate limit exceeded", status=429)
        if retry_after:
            # Tell the client when the window frees up so it backs off instead of retrying
            # into the same block. utils/ratelimit.py
            response["Retry-After"] = str(retry_after)
        return response

    def expire_after(self):
        "Used for setting the memcached cache expiry"
        return (self.minutes + 1) * 60


class ratelimit_post(ratelimit):
    "Rate limit POSTs - can be used to protect a login form"
    key_field = None  # If provided, this POST var will affect the rate limit

    def should_ratelimit(self, request):
        return request.method == "POST"

    def key_extra(self, request):
        # IP address and key_field (if it is set)
        extra = super(ratelimit_post, self).key_extra(request)
        if self.key_field:
            value = hashlib.sha1((request.POST.get(self.key_field, "")).encode("utf-8")).hexdigest()
            extra += "-" + value
        return extra


class ratelimit_by_url_user(ratelimit):
    """Rate limit based on a user_id extracted from the URL path, not the requester.

    Use this for public/anonymous endpoints where the target resource belongs to
    a specific user (e.g., RSS feeds, public profiles). All requests for resources
    belonging to the same user share one rate limit.

    Set `user_id_path_index` to specify which path segment contains the user_id.
    Default is 2 for paths like /reader/folder_rss/{user_id}/...
    """

    user_id_path_index = 2  # Path segment index containing user_id

    def key_extra(self, request):
        path_parts = request.path.strip("/").split("/")
        if len(path_parts) > self.user_id_path_index:
            user_id = path_parts[self.user_id_path_index]
            return f"url-user-{user_id}"
        return super().key_extra(request)

    def log_path(self, request):
        """Mask the segment after the user id before the path is logged. On
        /reader/folder_rss/<user_id>/<secret_token>/... that segment is the account's
        secret token, which autologin also accepts, so it must never land in a log line.
        utils/ratelimit.py"""
        path_parts = request.path.strip("/").split("/")
        token_index = self.user_id_path_index + 1
        if len(path_parts) > token_index:
            path_parts[token_index] = "<token>"
        return "/" + "/".join(path_parts)
