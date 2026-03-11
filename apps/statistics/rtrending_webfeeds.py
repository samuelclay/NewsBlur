import datetime
import hashlib

import redis
from django.conf import settings


class RTrendingWebFeed:
    """
    Tracks web feed usage events: analyses, subscriptions, hint refinements,
    variant selections, and re-analyses.

    Redis Key Structure:
    - wfAna:{date}       -> sorted set {url_hash: count} for analyses
    - wfSub:{date}       -> sorted set {url_hash: count} for subscriptions
    - wfAnaUsers:{date}  -> set of user IDs who analyzed
    - wfSubUsers:{date}  -> set of user IDs who subscribed
    - wfHints:{date}     -> integer counter for hint/refine analyses
    - wfReanalyze:{date} -> integer counter for re-analyses
    - wfVariant:{date}   -> sorted set {variant_index: count}
    - wfAnaSuccess:{date} -> integer counter for successful analyses
    - wfAnaFail:{date}    -> integer counter for failed analyses

    All keys expire after 35 days.
    """

    TTL_DAYS = 35

    @classmethod
    def _redis(cls):
        return redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

    @classmethod
    def _today(cls):
        return datetime.date.today().strftime("%Y-%m-%d")

    @classmethod
    def _ttl(cls):
        return cls.TTL_DAYS * 24 * 60 * 60

    @classmethod
    def _url_hash(cls, url):
        return hashlib.sha256(url.encode("utf-8")).hexdigest()[:16]

    @classmethod
    def record_analysis(cls, user_id, url, has_hint=False):
        r = cls._redis()
        today = cls._today()
        ttl = cls._ttl()
        url_hash = cls._url_hash(url)

        pipe = r.pipeline()
        pipe.zincrby(f"wfAna:{today}", 1, url_hash)
        pipe.expire(f"wfAna:{today}", ttl)
        pipe.sadd(f"wfAnaUsers:{today}", str(user_id))
        pipe.expire(f"wfAnaUsers:{today}", ttl)
        if has_hint:
            pipe.incr(f"wfHints:{today}")
            pipe.expire(f"wfHints:{today}", ttl)
        pipe.execute()

    @classmethod
    def record_reanalysis(cls, user_id):
        r = cls._redis()
        today = cls._today()
        ttl = cls._ttl()

        pipe = r.pipeline()
        pipe.incr(f"wfReanalyze:{today}")
        pipe.expire(f"wfReanalyze:{today}", ttl)
        pipe.sadd(f"wfAnaUsers:{today}", str(user_id))
        pipe.expire(f"wfAnaUsers:{today}", ttl)
        pipe.execute()

    @classmethod
    def record_analysis_result(cls, success=True):
        r = cls._redis()
        today = cls._today()
        ttl = cls._ttl()

        key = f"wfAnaSuccess:{today}" if success else f"wfAnaFail:{today}"
        pipe = r.pipeline()
        pipe.incr(key)
        pipe.expire(key, ttl)
        pipe.execute()

    @classmethod
    def record_subscription(cls, user_id, url, variant_index):
        r = cls._redis()
        today = cls._today()
        ttl = cls._ttl()
        url_hash = cls._url_hash(url)

        pipe = r.pipeline()
        pipe.zincrby(f"wfSub:{today}", 1, url_hash)
        pipe.expire(f"wfSub:{today}", ttl)
        pipe.sadd(f"wfSubUsers:{today}", str(user_id))
        pipe.expire(f"wfSubUsers:{today}", ttl)
        pipe.zincrby(f"wfVariant:{today}", 1, str(variant_index))
        pipe.expire(f"wfVariant:{today}", ttl)
        pipe.execute()

    @classmethod
    def get_daily_totals(cls, days=7):
        """Get daily totals for analyses, subscriptions, and unique users."""
        r = cls._redis()
        results = []

        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")

            pipe = r.pipeline()
            pipe.zrange(f"wfAna:{day}", 0, -1, withscores=True)
            pipe.zrange(f"wfSub:{day}", 0, -1, withscores=True)
            pipe.scard(f"wfAnaUsers:{day}")
            vals = pipe.execute()

            analyses = sum(int(s) for _, s in vals[0])
            subscriptions = sum(int(s) for _, s in vals[1])
            unique_users = vals[2]

            results.append((day, analyses, subscriptions, unique_users))

        return results

    @classmethod
    def get_stats_for_prometheus(cls):
        r = cls._redis()
        today = cls._today()

        pipe = r.pipeline()
        pipe.zrange(f"wfAna:{today}", 0, -1, withscores=True)  # 0: analyses
        pipe.zrange(f"wfSub:{today}", 0, -1, withscores=True)  # 1: subscriptions
        pipe.scard(f"wfAnaUsers:{today}")  # 2: unique analyzing users
        pipe.scard(f"wfSubUsers:{today}")  # 3: unique subscribing users
        pipe.get(f"wfHints:{today}")  # 4: hints
        pipe.get(f"wfReanalyze:{today}")  # 5: re-analyses
        pipe.zrange(f"wfVariant:{today}", 0, -1, withscores=True)  # 6: variant choices
        pipe.get(f"wfAnaSuccess:{today}")  # 7: successes
        pipe.get(f"wfAnaFail:{today}")  # 8: failures
        vals = pipe.execute()

        analyses_total = sum(int(s) for _, s in vals[0])
        unique_urls_analyzed = len(vals[0])
        subscriptions_total = sum(int(s) for _, s in vals[1])
        unique_urls_subscribed = len(vals[1])
        unique_users_analyzing = vals[2]
        unique_users_subscribing = vals[3]
        hints = int(vals[4] or 0)
        reanalyses = int(vals[5] or 0)
        variant_choices = {(v.decode() if isinstance(v, bytes) else v): int(s) for v, s in vals[6]}
        successes = int(vals[7] or 0)
        failures = int(vals[8] or 0)

        conversion_pct = 0
        if analyses_total > 0:
            conversion_pct = round(subscriptions_total / analyses_total * 100, 1)

        return {
            "analyses_today": analyses_total,
            "analyses_with_hint_today": hints,
            "reanalyses_today": reanalyses,
            "subscriptions_today": subscriptions_total,
            "unique_urls_analyzed_today": unique_urls_analyzed,
            "unique_urls_subscribed_today": unique_urls_subscribed,
            "unique_users_analyzing_today": unique_users_analyzing,
            "unique_users_subscribing_today": unique_users_subscribing,
            "analysis_success_today": successes,
            "analysis_fail_today": failures,
            "variant_choices": variant_choices,
            "conversion_rate_pct": conversion_pct,
        }
