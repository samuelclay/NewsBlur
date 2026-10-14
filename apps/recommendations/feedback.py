"""feedback.py: Account-owned recommendation preferences and their current timeline."""

import datetime

from bson import ObjectId
from django.core import signing
from django.views.decorators.csrf import ensure_csrf_cookie
from django.views.decorators.http import require_GET
from mongoengine.queryset.visitor import Q

from apps.recommendations.models import MRecommendationFeedback
from apps.rss_feeds.models import Feed
from utils import json_functions as json
from utils.user_functions import ajax_login_required

CURSOR_SALT = "recommendation-feedback"
PAGE_SIZE = 20


def feedback_summary(user_id):
    today = datetime.datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    start = today - datetime.timedelta(days=29)
    result = list(
        MRecommendationFeedback.objects(user_id=user_id, value__in=[-1, 1]).aggregate(
            {
                "$facet": {
                    "totals": [{"$group": {"_id": "$value", "count": {"$sum": 1}}}],
                    "days": [
                        {
                            "$match": {
                                "updated_date": {"$gte": start, "$lt": today + datetime.timedelta(days=1)}
                            }
                        },
                        {
                            "$group": {
                                "_id": {
                                    "date": {
                                        "$dateToString": {"format": "%Y-%m-%d", "date": "$updated_date"}
                                    },
                                    "value": "$value",
                                },
                                "count": {"$sum": 1},
                            }
                        },
                    ],
                }
            }
        )
    )[0]
    counts = {row["_id"]: row["count"] for row in result["totals"]}
    days = {(row["_id"]["date"], row["_id"]["value"]): row["count"] for row in result["days"]}
    dates = [(start + datetime.timedelta(days=i)).strftime("%Y-%m-%d") for i in range(30)]
    return dict(
        more=counts.get(1, 0),
        less=counts.get(-1, 0),
        days=[dict(date=day, more=days.get((day, 1), 0), less=days.get((day, -1), 0)) for day in dates],
    )


@ajax_login_required
@require_GET
@ensure_csrf_cookie
@json.json_view
def story_feedback_history(request):
    user_id = request.user.pk
    if request.GET.get("summary") == "1":
        return dict(code=1, summary=feedback_summary(user_id))
    value = request.GET.get("value", "1")
    if value not in ("-1", "1"):
        return dict(code=-1, message="Choose More or Less preferences.")
    value = int(value)
    query = MRecommendationFeedback.objects(user_id=user_id, value=value)
    cursor = request.GET.get("cursor")
    if cursor:
        try:
            boundary = signing.loads(cursor, salt=CURSOR_SALT, max_age=3600)
            if boundary["user"] != user_id or boundary["value"] != value:
                raise ValueError("Wrong preference list")
            date = datetime.datetime.fromisoformat(boundary["date"])
            query = query.filter(
                Q(updated_date__lt=date) | Q(updated_date=date, id__lt=ObjectId(boundary["id"]))
            )
        except (signing.BadSignature, ValueError, KeyError, TypeError):
            return dict(code=-1, message="This list has expired. Reopen your preferences to refresh it.")
    rows = list(
        query.exclude("story_excerpt", "story_tags").order_by("-updated_date", "-id")[: PAGE_SIZE + 1]
    )
    next_cursor = None
    if len(rows) > PAGE_SIZE:
        rows = rows[:PAGE_SIZE]
        last = rows[-1]
        next_cursor = signing.dumps(
            dict(user=user_id, value=value, date=last.updated_date.isoformat(), id=str(last.pk)),
            salt=CURSOR_SALT,
        )
    feeds = {
        feed.pk: dict(id=feed.pk, feed_title=feed.feed_title)
        for feed in Feed.objects.filter(pk__in={row.story_feed_id for row in rows}).only("pk", "feed_title")
    }
    return dict(
        code=1,
        summary=feedback_summary(user_id),
        stories=[
            dict(
                story_hash=row.story_hash,
                story_title=row.story_title,
                story_permalink=row.story_permalink,
                story_feed_id=row.story_feed_id,
                value=row.value,
                updated_date=row.updated_date.isoformat() + "Z",
            )
            for row in rows
        ],
        feeds=feeds,
        next_cursor=next_cursor,
    )
