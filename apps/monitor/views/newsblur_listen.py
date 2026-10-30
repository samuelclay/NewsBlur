import datetime
import json

import redis
from django.conf import settings
from django.shortcuts import render
from django.views import View

from apps.listen.models import LENGTH_BUCKETS, MListenDaily, MListenUsage
from apps.profile.models import Profile
from utils.llm_costs import LLMCostTracker

TOP_VOICES = 20
SPEED_BUCKETS = [
    ("under_0.9", 0.9),
    ("0.9_to_1.1", 1.1),
    ("1.1_to_1.5", 1.5),
    ("1.5_to_2", 2.0),
    ("over_2", None),
]
ALLTIME_CACHE_SECONDS = 60 * 60
PROFILE_CHUNK = 1000


def _label(value):
    """Prometheus label values can't contain quotes, backslashes or newlines."""
    return str(value or "unknown").replace("\\", "").replace('"', "'").replace("\n", " ")


class Listen(View):
    def get(self, request):
        """
        Prometheus metrics endpoint for Listen (stories read aloud, apps/listen).

        Listening time comes from MListenDaily, which the players fill through POST /listen/progress with time
        actually played. Generation, caching, previews and refusals come from MListenUsage.

        Tracks:
        - Listeners, unique stories and unique feeds (daily, monthly, all time)
        - Minutes listened and minutes of audio heard (daily, monthly, all time) and stories finished
        - Minutes and listeners by language, story length and plan (30 days)
        - Top voices, voice sources, delivery presets and playback speeds (30 days)
        - Auto-continue, follow-along and hidden Listen button among listeners
        - The free preview funnel and ElevenLabs characters, cost and cache hit rate
        """
        now = datetime.datetime.utcnow()
        today = now.strftime("%Y-%m-%d")
        month_start = (now - datetime.timedelta(days=29)).strftime("%Y-%m-%d")
        day_ago = now - datetime.timedelta(days=1)
        month_ago = now - datetime.timedelta(days=30)

        chart_name = "listen"
        chart_type = "gauge"
        lines = {}

        def metric(name, value, **labels):
            label_text = ",".join(
                [f'metric="{name}"'] + [f'{key}="{_label(val)}"' for key, val in labels.items()]
            )
            lines[f"{name}:{label_text}"] = f"{chart_name}{{{label_text}}} {round(value, 2)}"

        periods = {"daily": {"date": today}, "monthly": {"date": {"$gte": month_start}}}
        for period, match in periods.items():
            for name, value in self.period_totals(match).items():
                metric(name, value, period=period)
        for name, value in self.alltime_totals().items():
            metric(name, value, period="alltime")

        month = {"date": {"$gte": month_start}}
        # Every length bucket is always present, so the length chart keeps its order; real values replace these.
        for bucket, _ in LENGTH_BUCKETS:
            metric("stories_by_length", 0, length=bucket)
        for field, label in (("language", "language"), ("length_bucket", "length"), ("plan_tier", "tier")):
            for row in self.breakdown(month, f"${field}"):
                metric(f"minutes_by_{label}", row["seconds"] / 60, **{label: row["_id"]})
                metric(f"listeners_by_{label}", row["listeners"], **{label: row["_id"]})
                metric(f"stories_by_{label}", row["stories"], **{label: row["_id"]})

        for row in self.top_voices(month):
            metric("voice_minutes", row["seconds"] / 60, voice=row["name"], voice_id=row["_id"])
            metric("voice_listeners", row["listeners"], voice=row["name"], voice_id=row["_id"])
        for field, label in (("voice_source", "source"), ("delivery", "delivery")):
            for row in self.breakdown(month, f"${field}"):
                metric(f"minutes_by_{label}", row["seconds"] / 60, **{label: row["_id"]})
                metric(f"listeners_by_{label}", row["listeners"], **{label: row["_id"]})
        for bucket, minutes in self.speed_minutes(month).items():
            metric("minutes_by_speed", minutes, speed=bucket)

        for name, value in self.settings_counts(month).items():
            metric(name, value)
        for name, value in self.preview_funnel(month, month_ago).items():
            metric(name, value, period="monthly")
        for period, since in (("daily", day_ago), ("monthly", month_ago)):
            for name, value in self.generation_totals(since).items():
                metric(name, value, period=period)
            for reason, row in self.denials(since).items():
                metric("denied_requests", row["count"], reason=reason, period=period)
                metric("denied_users", row["users"], reason=reason, period=period)

        context = {
            "data": lines,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")

    # Listening time ---------------------------------------------------------------------------------------
    def distinct_count(self, collection, match, field):
        result = list(
            collection.aggregate([{"$match": match}, {"$group": {"_id": field}}, {"$count": "count"}])
        )
        return result[0]["count"] if result else 0

    def period_totals(self, match):
        collection = MListenDaily._get_collection()
        sums = list(
            collection.aggregate(
                [
                    {"$match": match},
                    {
                        "$group": {
                            "_id": None,
                            "listen_seconds": {"$sum": "$listen_seconds"},
                            "audio_seconds": {"$sum": "$audio_seconds"},
                            "finished": {"$sum": {"$cond": ["$finished", 1, 0]}},
                        }
                    },
                ]
            )
        )
        sums = sums[0] if sums else {"listen_seconds": 0, "audio_seconds": 0, "finished": 0}
        return {
            "listeners": self.distinct_count(collection, match, "$user_id"),
            "stories": self.distinct_count(collection, match, "$story_hash"),
            "feeds": self.distinct_count(collection, match, "$feed_id"),
            "minutes_listened": sums["listen_seconds"] / 60,
            "audio_minutes": sums["audio_seconds"] / 60,
            "stories_finished": sums["finished"],
        }

    def alltime_totals(self):
        """All-time totals scan every document, so they're cached for an hour."""
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        cached = r.get("monitor:listen:alltime")
        if cached:
            return json.loads(cached)
        totals = self.period_totals({})
        r.set("monitor:listen:alltime", json.dumps(totals), ex=ALLTIME_CACHE_SECONDS)
        return totals

    def breakdown(self, match, field):
        return MListenDaily._get_collection().aggregate(
            [
                {"$match": match},
                {
                    "$group": {
                        "_id": field,
                        "seconds": {"$sum": "$listen_seconds"},
                        "users": {"$addToSet": "$user_id"},
                        "story_hashes": {"$addToSet": "$story_hash"},
                    }
                },
                {
                    "$project": {
                        "seconds": 1,
                        "listeners": {"$size": "$users"},
                        "stories": {"$size": "$story_hashes"},
                    }
                },
            ]
        )

    def top_voices(self, match):
        return MListenDaily._get_collection().aggregate(
            [
                {"$match": match},
                {
                    "$group": {
                        "_id": "$voice_id",
                        "name": {"$last": "$voice_name"},
                        "seconds": {"$sum": "$listen_seconds"},
                        "users": {"$addToSet": "$user_id"},
                    }
                },
                {"$project": {"name": 1, "seconds": 1, "listeners": {"$size": "$users"}}},
                {"$sort": {"seconds": -1}},
                {"$limit": TOP_VOICES},
            ]
        )

    def speed_minutes(self, match):
        """Minutes listened at each average playback speed (audio heard over time spent, per story and day)."""
        minutes = {bucket: 0 for bucket, _ in SPEED_BUCKETS}
        rows = MListenDaily._get_collection().aggregate(
            [
                {"$match": dict(match, listen_seconds={"$gt": 0})},
                {
                    "$project": {
                        "listen_seconds": 1,
                        "speed": {"$divide": ["$audio_seconds", "$listen_seconds"]},
                    }
                },
            ]
        )
        for row in rows:
            for bucket, upper in SPEED_BUCKETS:
                if upper is None or row["speed"] < upper - 0.001:
                    minutes[bucket] += row["listen_seconds"] / 60
                    break
        return minutes

    def settings_counts(self, match):
        """Listen preferences among the month's listeners, read from their synced preferences."""
        user_ids = MListenDaily._get_collection().distinct("user_id", match)
        counts = {"auto_continue_on": 0, "follow_along_on": 0, "listen_button_hidden": 0}
        for start in range(0, len(user_ids), PROFILE_CHUNK):
            chunk = user_ids[start : start + PROFILE_CHUNK]
            for preferences in Profile.objects.filter(user_id__in=chunk).values_list(
                "preferences", flat=True
            ):
                try:
                    preferences = json.loads(preferences or "{}")
                except ValueError:
                    preferences = {}
                if preferences.get("listen_auto_continue", True) not in (False, "false"):
                    counts["auto_continue_on"] += 1
                if preferences.get("listen_highlight", True) not in (False, "false"):
                    counts["follow_along_on"] += 1
                if preferences.get("show_sideoption_listen", True) in (False, "false"):
                    counts["listen_button_hidden"] += 1
        counts["settings_listeners"] = len(user_ids)
        return counts

    # Previews and generation ----------------------------------------------------------------------------
    def preview_funnel(self, month, since):
        usage = MListenUsage._get_collection()
        sampled = usage.distinct(
            "user_id", {"kind": "segment", "is_sample": True, "created_at": {"$gte": since}}
        )
        hit_limit = usage.distinct(
            "user_id", {"kind": "denied", "reason": "sample_limit", "created_at": {"$gte": since}}
        )
        completed = MListenDaily._get_collection().distinct(
            "user_id", dict(month, is_preview=True, preview_completed=True)
        )
        upgraded = 0
        for start in range(0, len(sampled), PROFILE_CHUNK):
            chunk = sampled[start : start + PROFILE_CHUNK]
            upgraded += Profile.objects.filter(user_id__in=chunk, is_archive=True).count()
            upgraded += Profile.objects.filter(user_id__in=chunk, is_pro=True, is_archive=False).count()
        return {
            "preview_sampled_users": len(sampled),
            "preview_completed_users": len(completed),
            "preview_limit_users": len(hit_limit),
            "preview_upgraded_users": upgraded,
        }

    def generation_totals(self, since):
        rows = MListenUsage._get_collection().aggregate(
            [
                {"$match": {"kind": {"$in": ["segment", "preview"]}, "created_at": {"$gte": since}}},
                {
                    "$group": {
                        "_id": {"kind": "$kind", "cached": "$cached", "model": "$model"},
                        "count": {"$sum": 1},
                        "characters": {"$sum": "$characters"},
                    }
                },
            ]
        )
        totals = {
            "segments_generated": 0,
            "segments_cached": 0,
            "previews_generated": 0,
            "previews_cached": 0,
            "characters_generated": 0,
            "cost_usd": 0.0,
        }
        for row in rows:
            kind, cached = row["_id"]["kind"], row["_id"]["cached"]
            totals[f"{kind}s_{'cached' if cached else 'generated'}"] += row["count"]
            if not cached:
                totals["characters_generated"] += row["characters"]
                totals["cost_usd"] += LLMCostTracker.calculate_cost(
                    row["_id"]["model"], characters=row["characters"]
                )
        served = totals["segments_generated"] + totals["segments_cached"]
        totals["cache_hit_rate"] = totals["segments_cached"] / served if served else 0
        return totals

    def denials(self, since):
        rows = MListenUsage._get_collection().aggregate(
            [
                {"$match": {"kind": "denied", "created_at": {"$gte": since}}},
                {"$group": {"_id": "$reason", "count": {"$sum": 1}, "users": {"$addToSet": "$user_id"}}},
            ]
        )
        result = {
            reason: {"count": 0, "users": 0}
            for reason in ("sample_limit", "cap_reached", "preview_ended", "preview_limit")
        }
        for row in rows:
            result[row["_id"] or "unknown"] = {"count": row["count"], "users": len(row["users"])}
        return result
