import datetime
import json
from urllib.parse import urlparse

import redis
import requests
from django.conf import settings

from utils import log as logging


class RScrapingBee:
    """
    Tracks every ScrapingBee proxy request NewsBlur makes so credit burn shows up in
    Grafana instead of only in ScrapingBee's billing emails.

    Recorded at each call site:
    - utils/feed_fetcher.py: forbidden feed fetches ("feed") and add-feed discovery ("discovery")
    - apps/rss_feeds/page_importer.py: blocked original story pages ("original_story")
    - utils/webfeed_fetcher.py: web feed fetches ("webfeed")
    - apps/webfeed/tasks.py: web feed analysis/preview fetches ("webfeed_preview")

    Exported to Prometheus by apps/monitor/views/newsblur_scrapingbee.py.

    Redis Key Structure (REDIS_STATISTICS_POOL, like apps/statistics/rtrending_webfeeds.py):
    - sbCalls:{date}         -> hash {"{source}:{status}": count} of requests by call site and result
    - sbCredits:{date}       -> hash {source: credits} of credits charged, from the Spb-cost header
    - sbDomains:{date}       -> sorted set {host: requests} of requests per target host
    - sbDomainCredits:{date} -> sorted set {host: credits} of credits charged per target host
    - sbUsage                -> cached JSON of ScrapingBee's account usage API (5 minute TTL)

    Daily keys expire after 35 days.

    A single host can also burn the whole plan: one user's 1,700 AbeBooks search web
    feeds cost ~43K credits/day in September 2026 because AbeBooks challenged some task
    server IPs and every challenged fetch was proxied. host_over_budget() caps the credits
    any one host may spend per day (settings.SCRAPINGBEE_HOST_DAILY_CREDIT_CAP); callers
    skip the paid proxies past the cap and count the skip under status "capped".
    """

    TTL_DAYS = 35
    USAGE_CACHE_SECONDS = 300
    USAGE_API_URL = "https://app.scrapingbee.com/api/v1/usage"
    TOP_DOMAINS = 20
    SOURCES = ("feed", "discovery", "original_story", "webfeed", "webfeed_preview")
    # ScrapingBee only bills 200 and 404 responses. 500 means the target site blocked
    # even the proxy; "error" means the request to ScrapingBee itself raised.
    # "capped" and "dormant" are proxy requests that were skipped, not made: the host was
    # over its daily credit cap, or the feed's only subscriber hasn't been seen in a year.
    STATUSES = ("200", "304", "404", "500", "other", "error", "capped", "dormant")
    # Fallback when settings.SCRAPINGBEE_HOST_DAILY_CREDIT_CAP isn't set. Only the hottest
    # few hosts (rsshub.app, deviantart, craigslist) spend even half this in a normal day.
    DEFAULT_HOST_DAILY_CREDIT_CAP = 1000

    @classmethod
    def _redis(cls):
        return redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

    @classmethod
    def _date(cls, day=None):
        return (day or datetime.date.today()).strftime("%Y-%m-%d")

    @classmethod
    def _ttl(cls):
        return cls.TTL_DAYS * 24 * 60 * 60

    @classmethod
    def _host(cls, url):
        if not url:
            return None
        try:
            host = urlparse(url if "://" in url else "http://%s" % url).netloc.lower()
        except ValueError:
            return None
        if host.startswith("www."):
            host = host[4:]
        return host or None

    @classmethod
    def status_bucket(cls, status_code):
        if status_code is None:
            return "error"
        if status_code in (200, 304, 404, 500):
            return str(status_code)
        return "other"

    @classmethod
    def credits_for_response(cls, response):
        """
        Credits ScrapingBee charged for a response, read from its Spb-cost header.
        ScrapingBee bills 200 and 404 responses and nothing else, which is the fallback
        when the header is missing.
        """
        headers = getattr(response, "headers", None) or {}
        try:
            return int(headers.get("Spb-cost"))
        except (TypeError, ValueError):
            return 1 if response.status_code in (200, 404) else 0

    @classmethod
    def record(cls, source, status_code=None, url=None, credits=0):
        """Count one ScrapingBee request. Never raises: stats must not break a fetch."""
        try:
            r = cls._redis()
            today = cls._date()
            ttl = cls._ttl()
            credits = int(credits or 0)
            host = cls._host(url)

            pipe = r.pipeline()
            pipe.hincrby(f"sbCalls:{today}", f"{source}:{cls.status_bucket(status_code)}", 1)
            pipe.expire(f"sbCalls:{today}", ttl)
            pipe.hincrby(f"sbCredits:{today}", source, credits)
            pipe.expire(f"sbCredits:{today}", ttl)
            if host:
                pipe.zincrby(f"sbDomains:{today}", 1, host)
                pipe.expire(f"sbDomains:{today}", ttl)
                if credits:
                    pipe.zincrby(f"sbDomainCredits:{today}", credits, host)
                    pipe.expire(f"sbDomainCredits:{today}", ttl)
            pipe.execute()
        except Exception as e:
            logging.debug(
                " ***> ScrapingBee stats not recorded (%s, status %s): %s" % (source, status_code, e)
            )

    @classmethod
    def host_daily_credit_cap(cls):
        return int(getattr(settings, "SCRAPINGBEE_HOST_DAILY_CREDIT_CAP", cls.DEFAULT_HOST_DAILY_CREDIT_CAP))

    @classmethod
    def host_credits_today(cls, url):
        host = cls._host(url)
        if not host:
            return 0
        try:
            return int(cls._redis().zscore(f"sbDomainCredits:{cls._date()}", host) or 0)
        except Exception as e:
            logging.debug(" ***> ScrapingBee host credits unavailable for %s: %s" % (host, e))
            return 0

    @classmethod
    def host_over_budget(cls, url):
        """True once a host has spent its daily credit cap, so callers skip the paid proxies."""
        return cls.host_credits_today(url) >= cls.host_daily_credit_cap()

    @classmethod
    def record_skip(cls, source, reason, url=None):
        """
        Count a proxy request that was deliberately skipped. `reason` becomes the status
        label on the dashboard: "capped" (host over its daily credit cap) or "dormant" (the
        feed's only subscriber hasn't been seen in a year). Never raises.
        """
        try:
            r = cls._redis()
            today = cls._date()
            pipe = r.pipeline()
            pipe.hincrby(f"sbCalls:{today}", f"{source}:{reason}", 1)
            pipe.expire(f"sbCalls:{today}", cls._ttl())
            pipe.execute()
        except Exception as e:
            logging.debug(" ***> ScrapingBee %s stat not recorded (%s): %s" % (reason, source, e))

    @classmethod
    def record_capped(cls, source, url=None):
        """Count a proxy request that was skipped because its host is over the daily cap."""
        cls.record_skip(source, "capped", url=url)

    @classmethod
    def record_response(cls, source, response, url=None):
        """Count a completed ScrapingBee request, charging whatever its Spb-cost header says."""
        cls.record(
            source,
            response.status_code,
            url=url,
            credits=cls.credits_for_response(response),
        )

    @classmethod
    def get_stats_for_prometheus(cls):
        r = cls._redis()
        today = cls._date()

        stats = {
            "calls": {},
            "credits": {},
            "calls_today": 0,
            "credits_today": 0,
            "top_domains": [],
            "host_credit_cap": cls.host_daily_credit_cap(),
            "hosts_over_cap": 0,
        }
        for field, count in r.hgetall(f"sbCalls:{today}").items():
            source, status = field.split(":", 1)
            stats["calls"][(source, status)] = int(count)
            stats["calls_today"] += int(count)
        for source, amount in r.hgetall(f"sbCredits:{today}").items():
            stats["credits"][source] = int(amount)
            stats["credits_today"] += int(amount)

        domain_requests = dict(r.zrevrange(f"sbDomains:{today}", 0, -1, withscores=True))
        for host, credits in r.zrevrange(f"sbDomainCredits:{today}", 0, cls.TOP_DOMAINS - 1, withscores=True):
            stats["top_domains"].append((host, int(credits), int(domain_requests.get(host, 0))))
        stats["hosts_over_cap"] = r.zcount(f"sbDomainCredits:{today}", stats["host_credit_cap"], "+inf")

        return stats

    @classmethod
    def get_daily_totals(cls, days=7):
        """Returns [(date_str, requests, credits)] for the last N days, oldest first."""
        r = cls._redis()
        totals = []
        for offset in range(days - 1, -1, -1):
            day = cls._date(datetime.date.today() - datetime.timedelta(days=offset))
            calls = sum(int(count) for count in r.hgetall(f"sbCalls:{day}").values())
            credits = sum(int(amount) for amount in r.hgetall(f"sbCredits:{day}").values())
            totals.append((day, calls, credits))
        return totals

    @classmethod
    def get_account_usage(cls):
        """
        ScrapingBee's usage API: credits used vs the plan's maximum and the renewal date.
        Cached for 5 minutes so Prometheus scrapes don't hammer it. Returns {} when no API
        key is configured or the API is unreachable.
        """
        api_key = getattr(settings, "SCRAPINGBEE_API_KEY", None)
        if not api_key:
            return {}

        r = cls._redis()
        cached = r.get("sbUsage")
        if cached:
            try:
                return json.loads(cached)
            except ValueError:
                pass

        try:
            response = requests.get(cls.USAGE_API_URL, params={"api_key": api_key}, timeout=10)
            if response.status_code != 200:
                logging.debug(" ***> ScrapingBee usage API returned %s" % response.status_code)
                return {}
            data = response.json()
        except (requests.RequestException, ValueError) as e:
            logging.debug(" ***> ScrapingBee usage API failed: %s" % e)
            return {}

        used = int(data.get("used_api_credit") or 0)
        maximum = int(data.get("max_api_credit") or 0)
        usage = {
            "used": used,
            "max": maximum,
            "remaining": max(maximum - used, 0),
            "used_pct": round(100.0 * used / maximum, 1) if maximum else 0.0,
            "concurrency": int(data.get("current_concurrency") or 0),
            "max_concurrency": int(data.get("max_concurrency") or 0),
            "renewal": data.get("renewal_subscription_date"),
            "days_to_renewal": cls._days_until(data.get("renewal_subscription_date")),
        }
        r.set("sbUsage", json.dumps(usage), ex=cls.USAGE_CACHE_SECONDS)
        return usage

    @classmethod
    def _days_until(cls, iso_timestamp):
        if not iso_timestamp:
            return 0.0
        try:
            renewal = datetime.datetime.fromisoformat(iso_timestamp.replace("Z", ""))
        except ValueError:
            return 0.0
        seconds = (renewal - datetime.datetime.utcnow()).total_seconds()
        return round(max(seconds, 0) / 86400.0, 2)
