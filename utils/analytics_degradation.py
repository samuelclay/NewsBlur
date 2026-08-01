"""Graceful degradation for the analytics MongoDB (utils/analytics_degradation.py).

The `nbanalytics` database stores page-load timings, feed-fetch timings, and
per-feed fetch history. None of it is required to serve a request or fetch a
feed, but every write to it used to happen inline. When the analytics server
went away, each page load blocked on pymongo's server selection until it timed
out, which saturated the web workers and took the whole site down.

Anything touching analytics should go through `skip_when_analytics_down`, which:

  1. Returns `default` immediately while the circuit breaker is open, so a dead
     analytics server costs one timeout per process per minute rather than one
     timeout per request.
  2. Swallows analytics connection errors so the caller carries on.
  3. Emails the admins at most once an hour, so the outage is visible without
     flooding the inbox.

The circuit breaker is deliberately process-local: it needs no network call on
the happy path, which matters because this sits in front of every page load.
The email throttle is in Redis so that all web and task servers share one
hourly budget between them.
"""

import functools
import time

import redis
from django.conf import settings
from django.core.mail import mail_admins
from mongoengine.connection import ConnectionFailure as MongoEngineConnectionFailure
from mongoengine.errors import OperationError
from pymongo.errors import PyMongoError

from utils import log as logging

# Errors that mean "the analytics database is unreachable or unusable". Kept
# narrow on purpose: a bug in our own analytics code should still raise loudly
# rather than be silently swallowed here.
ANALYTICS_EXCEPTIONS = (PyMongoError, MongoEngineConnectionFailure, OperationError)

# How long a process stops attempting analytics work after a failure. Long
# enough that a dead server is cheap, short enough that recovery is quick.
CIRCUIT_BREAKER_SECONDS = 60

# Admins get at most one "analytics is down" email per this many seconds,
# across every web and task server.
EMAIL_THROTTLE_SECONDS = 60 * 60
EMAIL_THROTTLE_KEY = "analytics_db_down_email_sent"

# Timestamp of the most recent failure, or None when analytics is believed up.
_circuit_opened_at = None


def analytics_available():
    """False while the circuit breaker is open from a recent analytics failure."""
    global _circuit_opened_at

    if _circuit_opened_at is None:
        return True
    if time.time() - _circuit_opened_at >= CIRCUIT_BREAKER_SECONDS:
        _circuit_opened_at = None
        return True
    return False


def record_analytics_failure(operation, exception):
    """Open the circuit breaker and let the admins know, at most hourly."""
    global _circuit_opened_at

    first_failure = _circuit_opened_at is None
    _circuit_opened_at = time.time()

    logging.debug(
        " ***> Analytics DB unavailable, skipping ~FR%s~SN for %ss: %s"
        % (operation, CIRCUIT_BREAKER_SECONDS, exception)
    )
    if first_failure:
        _email_admins_throttled(operation, exception)


def _email_admins_throttled(operation, exception):
    """Email the admins if nobody else has in the last EMAIL_THROTTLE_SECONDS.

    The Redis SET NX doubles as the throttle and the lock: exactly one process
    across the fleet wins the key each hour, and only that process sends.
    """
    try:
        r = redis.Redis(connection_pool=settings.REDIS_ANALYTICS_POOL)
        won_throttle = r.set(EMAIL_THROTTLE_KEY, "1", nx=True, ex=EMAIL_THROTTLE_SECONDS)
    except Exception as e:
        # Redis is down too. Losing the alert beats raising from a failure path.
        logging.debug(" ***> Couldn't throttle analytics alert email: %s" % e)
        return

    if not won_throttle:
        return

    subject = "Analytics DB unavailable on %s" % settings.SERVER_NAME
    message = (
        "The analytics MongoDB (nbanalytics) is unreachable.\n\n"
        "Server: %s\n"
        "Operation: %s\n"
        "Error: %r\n\n"
        "Analytics writes are being skipped for %s seconds at a time on each process, "
        "so the site and feed fetching keep working. Page load timings, feed fetch "
        "timings, and feed fetch history are not being recorded until this is fixed.\n\n"
        "This alert is throttled to once per hour."
        % (settings.SERVER_NAME, operation, exception, CIRCUIT_BREAKER_SECONDS)
    )
    mail_admins(subject, message, fail_silently=True)


def skip_when_analytics_down(default=None):
    """Return `default` instead of raising when the analytics DB is unavailable.

    Pass a callable as `default` when each caller needs its own fresh value
    (a new dict, say) rather than one shared between every skipped call.
    """

    def decorator(fn):
        @functools.wraps(fn)
        def wrapper(*args, **kwargs):
            if not analytics_available():
                return default() if callable(default) else default
            try:
                return fn(*args, **kwargs)
            except ANALYTICS_EXCEPTIONS as e:
                record_analytics_failure(fn.__qualname__, e)
                return default() if callable(default) else default

        return wrapper

    return decorator
