"""Exclude repeated coordinated sharing from public discovery, without hiding blurblogs."""

import datetime
import html
from collections import defaultdict
from itertools import combinations

from utils.story_functions import strip_tags

CAMPAIGN_DAYS = 3
CAMPAIGN_USERS = 3
COORDINATED_SHARE_MINUTES = 5


def _sharing_cohorts(shares, timed):
    """Return groups of readers, requiring a short sharing burst for blank comments."""
    if not timed:
        return [set(user_id for user_id, shared_date in shares)]

    shares = sorted(shares, key=lambda share: share[1])
    window = datetime.timedelta(minutes=COORDINATED_SHARE_MINUTES)
    cohorts = []
    right = 0
    previous_right = 0
    for left, (_, shared_date) in enumerate(shares):
        while right < len(shares) and shares[right][1] - shared_date <= window:
            right += 1
        # apps/social/discovery.py: A window contained in the previous one adds no cohort.
        if right > previous_right:
            users = {user_id for user_id, _ in shares[left:right]}
            if len(users) >= CAMPAIGN_USERS:
                cohorts.append(users)
        previous_right = right
    return cohorts


def coordinated_share_pairs(rows, now=None):
    """Find (user, feed) pairs repeating a comment or synchronized blank shares.

    Rows contain user_id, story_feed_id, story_hash, comments and shared_date. The
    same three readers must overlap on two distinct stories of the same feed.
    """
    now = now or datetime.datetime.now()
    cutoff = now - datetime.timedelta(days=CAMPAIGN_DAYS)
    groups = defaultdict(lambda: defaultdict(list))
    for row in rows:
        shared_date = row.get("shared_date")
        if not shared_date or not cutoff <= shared_date <= now:
            continue
        comment = " ".join(html.unescape(strip_tags(row.get("comments") or "")).casefold().split())
        groups[(row["story_feed_id"], comment)][row["story_hash"]].append((row["user_id"], shared_date))

    excluded_pairs = set()
    for (feed_id, comment), stories in groups.items():
        cohorts_by_story = [
            _sharing_cohorts(shares, timed=not comment)
            for shares in stories.values()
            if len({user_id for user_id, _ in shares}) >= CAMPAIGN_USERS
        ]
        for first, second in combinations(cohorts_by_story, 2):
            for first_users in first:
                for second_users in second:
                    common_users = first_users & second_users
                    if len(common_users) >= CAMPAIGN_USERS:
                        excluded_pairs.update((user_id, feed_id) for user_id in common_users)
    return excluded_pairs


def discovery_excluded_pairs(now=None):
    """Read only the recent sharing metadata needed by both public discovery paths."""
    from apps.social.models import MSharedStory

    now = now or datetime.datetime.now()
    rows = MSharedStory._get_collection().find(
        {"shared_date": {"$gte": now - datetime.timedelta(days=CAMPAIGN_DAYS), "$lte": now}},
        {
            "_id": 0,
            "user_id": 1,
            "story_feed_id": 1,
            "story_hash": 1,
            "comments": 1,
            "shared_date": 1,
        },
    )
    return coordinated_share_pairs(rows, now=now)
