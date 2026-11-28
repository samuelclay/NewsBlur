"""What the model sees about each of a user's sites, and which of those sites look dead.

gather_sites() describes every site that model_view() in apps/reorganize/derive.py lets the model
file: its title (the user's own name for it wins), address, tagline, popular tags, a few recent
headlines, stories per month and the open folders it sits in. Each text field is capped. Everything
comes from a handful of bulk queries, and a site in the folder tree with no subscription behind it
is left out.

dead_sites() flags sites by rule, never by the model. It queries stories one site at a time, but
only for the few sites the stored statistics cannot already show to be alive.
"""

import datetime
import html
import json
import re
import time
from dataclasses import dataclass
from typing import Optional

import redis
from django.conf import settings
from django.utils.html import strip_tags

from apps.reader.models import UserSubscription
from apps.reorganize.plan import ROOT_KEY
from apps.rss_feeds.models import Feed, FeedData, MStory

TITLE_LIMIT = 100
ADDRESS_LIMIT = 100
TAGLINE_LIMIT = 200
TAG_LIMIT = 40
TAGS_PER_SITE = 5
HEADLINE_LIMIT = 120
HEADLINES_PER_SITE = 3
FOLDER_LABEL_LIMIT = 200

# How the top level reads to the model where a folder path would go.
TOP_LEVEL = "(top level)"

# A site with a story this recent is never flagged.
RECENT_DAYS = 180
# A site whose latest story is older than this is quiet, and if it is also failing, gone.
LONG_QUIET_DAYS = 2 * 365


@dataclass
class Site:
    """One site the model may see, and what the dead-site rule reads about it."""

    feed_id: int
    title: str
    address: str
    tagline: str
    tags: list
    headlines: list
    stories_per_month: int
    folder_keys: list  # the open folder keys from model_view(), "root" for the top level
    folders: list  # those folders as the model reads them, from folder_label()
    muted: bool
    failing: bool
    last_story_date: Optional[datetime.datetime]
    stories_last_month: int
    created: Optional[datetime.date]
    newest_story_time: Optional[float] = None  # when its newest story in Redis was published

    def digest(self):
        """The site as an assign call shows it, leaving out the fields it has nothing for."""
        digest = {"id": self.feed_id, "title": self.title, "address": self.address}
        if self.tagline:
            digest["tagline"] = self.tagline
        if self.tags:
            digest["tags"] = self.tags
        if self.headlines:
            digest["headlines"] = self.headlines
        digest["stories_per_month"] = self.stories_per_month
        digest["folders"] = self.folders
        return digest

    def line(self):
        """The site as the design call lists it: id, title, address and the keys of its folders."""
        return [self.feed_id, self.title, self.address, self.folder_keys]


def folder_label(path):
    """How a folder path reads to the model: its names joined with " / ", or TOP_LEVEL."""
    return " / ".join(path)[:FOLDER_LABEL_LIMIT] if path else TOP_LEVEL


def gather_sites(user_id, view):
    """A Site for each site in `view` (from derive.model_view) the user is subscribed to, in its order."""
    labels = {folder["key"]: folder_label(folder["path"]) for folder in view["folders"]}
    labels[ROOT_KEY] = TOP_LEVEL
    feed_ids = list(view["sites"])

    subscriptions = {
        row["feed_id"]: row
        for row in UserSubscription.objects.filter(user_id=user_id, feed_id__in=feed_ids).values(
            "feed_id", "user_title", "active"
        )
    }
    feeds = {
        row["id"]: row
        for row in Feed.objects.filter(pk__in=list(subscriptions)).values(
            "id",
            "feed_title",
            "feed_link",
            "feed_address",
            "average_stories_per_month",
            "stories_last_month",
            "has_feed_exception",
            "last_story_date",
            "creation",
        )
    }
    data = {
        row["feed_id"]: row
        for row in FeedData.objects.filter(feed_id__in=list(feeds)).values(
            "feed_id", "feed_tagline", "popular_tags"
        )
    }
    newest = _newest_stories(list(feeds))
    titles = _story_titles([story_hash for stories in newest.values() for story_hash, _ in stories])

    sites = []
    for feed_id, placement in view["sites"].items():
        feed, subscription = feeds.get(feed_id), subscriptions.get(feed_id)
        if feed is None or subscription is None:
            continue
        feed_data = data.get(feed_id, {})
        stories = newest.get(feed_id, [])
        sites.append(
            Site(
                feed_id=feed_id,
                title=_text(subscription["user_title"] or feed["feed_title"], TITLE_LIMIT),
                address=_address(feed),
                tagline=_text(feed_data.get("feed_tagline"), TAGLINE_LIMIT),
                tags=_tags(feed_data.get("popular_tags")),
                headlines=[
                    _text(titles[story_hash], HEADLINE_LIMIT)
                    for story_hash, _ in stories
                    if titles.get(story_hash)
                ],
                stories_per_month=feed["average_stories_per_month"] or 0,
                folder_keys=list(placement["folders"]),
                folders=[labels[key] for key in placement["folders"] if key in labels],
                muted=not subscription["active"],
                failing=bool(feed["has_feed_exception"]),
                last_story_date=feed["last_story_date"],
                stories_last_month=feed["stories_last_month"] or 0,
                created=feed["creation"],
                newest_story_time=stories[0][1] if stories else None,
            )
        )
    return sites


def dead_sites(sites):
    """The dead entries for derive.build_proposal among `sites`, skipping muted ones.

    A site is "failing" when its feed is failing to fetch and it has no story in RECENT_DAYS, and
    "quiet" when it is not failing and its latest story is older than LONG_QUIET_DAYS, or it never
    had a story and its feed is that old. Each entry suggests "unsubscribe" for a failing site
    with no story in LONG_QUIET_DAYS or none ever, and "mute" otherwise. `since` is the month of
    the latest story as "YYYY-MM", or None, and the interface writes the sentence from it and
    `cause`.
    """
    now = datetime.datetime.utcnow()
    recent = now - datetime.timedelta(days=RECENT_DAYS)
    long_quiet = now - datetime.timedelta(days=LONG_QUIET_DAYS)

    entries = []
    for site in sites:
        if site.muted or not _might_be_dead(site, recent):
            continue
        latest = _latest_story_date(site.feed_id)
        if latest is not None and latest >= recent:
            continue
        gone_quiet = latest is None or latest < long_quiet
        if site.failing:
            cause, suggest = "failing", "unsubscribe" if gone_quiet else "mute"
        elif latest is not None and latest < long_quiet:
            cause, suggest = "quiet", "mute"
        elif latest is None and site.created is not None and site.created < long_quiet.date():
            cause, suggest = "quiet", "mute"
        else:
            continue
        entries.append(
            {
                "feed_id": site.feed_id,
                "reason": "",
                "suggest": suggest,
                "cause": cause,
                "since": latest.strftime("%Y-%m") if latest else None,
            }
        )
    return entries


def _might_be_dead(site, recent):
    """False only when the stored data shows a story since `recent`.

    A newest story in Redis is a real story. Feed.last_story_date is the latest story's date, except
    that calculate_last_story_date in apps/rss_feeds/models.py sets it to the current time for a
    feed with no stories, and such a feed counts no stories last month. So a recent date backed by
    a count above zero is a real story too.
    """
    if site.newest_story_time is not None and site.newest_story_time >= time.mktime(recent.timetuple()):
        return False
    return site.last_story_date is None or site.last_story_date < recent or site.stories_last_month == 0


def _latest_story_date(feed_id):
    story = MStory.objects(story_feed_id=feed_id).order_by("-story_date").only("story_date").first()
    return story.story_date if story else None


def _newest_stories(feed_ids):
    """{feed id: [(story hash, published time), ...]} for each site's newest stories in Redis."""
    r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
    pipeline = r.pipeline()
    for feed_id in feed_ids:
        pipeline.zrevrange("zF:%s" % feed_id, 0, HEADLINES_PER_SITE - 1, withscores=True)
    return {feed_id: stories for feed_id, stories in zip(feed_ids, pipeline.execute()) if stories}


def _story_titles(story_hashes):
    if not story_hashes:
        return {}
    stories = MStory.objects(story_hash__in=story_hashes).only("story_hash", "story_title")
    return {story.story_hash: story.story_title for story in stories}


def _address(feed):
    address = (feed["feed_link"] or feed["feed_address"] or "").strip()
    return _text(re.sub(r"^https?://(www\.)?", "", address).rstrip("/"), ADDRESS_LIMIT)


def _tags(popular_tags):
    """The most popular tag names, from FeedData.popular_tags' JSON list of [tag, count] pairs."""
    try:
        entries = json.loads(popular_tags) if popular_tags else []
    except ValueError:
        return []
    tags = []
    for entry in entries if isinstance(entries, list) else []:
        name = entry[0] if isinstance(entry, (list, tuple)) and entry else entry
        tag = _text(name, TAG_LIMIT)
        if tag and tag not in tags:
            tags.append(tag)
        if len(tags) == TAGS_PER_SITE:
            break
    return tags


def _text(value, limit):
    """`value` as one line of plain text, cut to `limit` characters."""
    if not isinstance(value, str):
        return ""
    return " ".join(html.unescape(strip_tags(value)).split())[:limit].rstrip()
