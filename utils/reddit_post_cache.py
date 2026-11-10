"""Recent Reddit posts per subreddit and per Reddit user, shared through Redis.

The hourly RedListen poller (utils/redlisten_poller.py) fetches every subreddit and
user that active feeds read in a few batched requests and drops the posts here, keyed
by target: "r:<subreddit>" or "u:<username>", always lowercase. A subreddit or user feed
fetch (utils/reddit_fetcher.py) then builds its Atom feed from these posts without
spending any RedListen budget, and a multireddit feed (r/a+b) merges its subreddits.

Each target keeps its newest POSTS_PER_TARGET posts, trimmed to the fields the feed
renders, as one JSON list in settings.REDIS_FEED_UPDATE_POOL that expires after a week
without new posts. See utils/reddit_post_cache.py.
"""

import json

import redis
from django.conf import settings

POSTS_KEY = "redlisten:posts:%s"
POSTS_PER_TARGET = 25
POSTS_TTL = 60 * 60 * 24 * 7
MAX_SELFTEXT_CHARS = 20000

# Everything utils/reddit_fetcher.py reads off a post, and nothing else.
KEPT_POST_FIELDS = (
    "id",
    "title",
    "selftext",
    "selftext_html",
    "author",
    "subreddit",
    "created_utc",
    "url",
    "permalink",
    "domain",
    "is_self",
    "over_18",
    "stickied",
    "link_flair_text",
    "media_urls",
    "thumbnail",
    "post_hint",
    "score",
    "num_comments",
)


def subreddit_target(name):
    return "r:%s" % name.lower()


def user_target(name):
    return "u:%s" % name.lower()


def trim_post(post):
    """Keep only the fields a feed renders, so a busy cache stays small."""
    trimmed = {field: post.get(field) for field in KEPT_POST_FIELDS if post.get(field) is not None}
    if trimmed.get("selftext") and len(trimmed["selftext"]) > MAX_SELFTEXT_CHARS:
        trimmed["selftext"] = trimmed["selftext"][:MAX_SELFTEXT_CHARS]
    return trimmed


class RedditPostCache:
    def __init__(self, r=None):
        self.r = r or redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)

    def target_posts(self, target):
        raw = self.r.get(POSTS_KEY % target)
        if not raw:
            return []
        try:
            return json.loads(raw)
        except ValueError:
            return []

    def add(self, target, posts):
        """Merge posts into a target's cache, newest first. Returns how many of them
        were not cached before and survived the trim, which is how the poller knows
        to schedule the target's feeds."""
        cached = self.target_posts(target)
        by_id = {post["id"]: post for post in cached if post.get("id")}
        known_ids = set(by_id)
        for post in posts:
            if post.get("id"):
                by_id[post["id"]] = trim_post(post)
        newest = sorted(by_id.values(), key=lambda post: post.get("created_utc") or 0, reverse=True)
        newest = newest[:POSTS_PER_TARGET]
        added = sum(1 for post in newest if post["id"] not in known_ids)
        if added or len(newest) != len(cached):
            self.r.set(POSTS_KEY % target, json.dumps(newest), ex=POSTS_TTL)
        return added

    def posts(self, targets, limit=POSTS_PER_TARGET):
        """The newest posts across one or more targets, newest first."""
        merged = {}
        for target in targets:
            for post in self.target_posts(target):
                merged[post["id"]] = post
        newest = sorted(merged.values(), key=lambda post: post.get("created_utc") or 0, reverse=True)
        return newest[:limit]

    def has_any(self, targets):
        return any(self.r.exists(POSTS_KEY % target) for target in targets)
