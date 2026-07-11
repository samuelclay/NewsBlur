"""
Hourly curation of the Global Shared Stories river.

The river used to be whatever the accounts followed by @popular happened to share, which
meant a handful of prolific sharers decided what everybody saw. Instead, gather every
story shared across NewsBlur in the last few hours, cap how many any one person can
contribute, and ask Claude Haiku to pick the ones actually worth reading, leaning on the
comment the sharer wrote as the strongest signal of a considered share.
"""

import datetime
import random
import re
import zlib

from django.contrib.auth.models import User
from django.utils.encoding import smart_str

from apps.social.rglobal import RGlobalSharedStory
from utils import log as logging
from utils.llm_costs import LLMCostTracker
from utils.story_functions import strip_tags

# apps/social/curation.py: A 6 hour window keeps the pool fresh without missing shares
# when an hourly run fails, since already-curated stories are filtered out anyway.
CANDIDATE_HOURS = 6
MAX_SHARES_PER_USER = 3
CANDIDATE_POOL_SIZE = 60
MAX_PICKS = 8
COMMENT_LENGTH = 400
EXCERPT_LENGTH = 300

SYSTEM_PROMPT = """You are the editor of NewsBlur's Global Shared Stories, a river of stories \
that NewsBlur readers have shared to their public blurblogs. Your job is to pick the shares \
that a curious, well-read stranger would be glad to have found.

Favor:
- Stories where the sharer wrote a comment that shows they actually read and thought about it.
- Reporting, essays, and analysis with something to say.
- Range. Do not pick several stories on the same event, from the same site, or from the same sharer.
- Stories from smaller or unfamiliar publications over stories everyone has already seen.

Reject:
- Press releases, marketing, listicles, SEO filler, and engagement bait.
- Breaking news commodity coverage that a dozen outlets ran identically.
- Anything whose interest depends on already following a niche drama.
- Sexually explicit content and gratuitous shock content.

Quality is the bar, not quantity. If only two stories are worth it, pick two. If none are, pick none.

Respond with JSON only, no prose and no code fences:
{"picks": [{"id": <candidate id>, "reason": "<up to 12 words>"}]}"""


def _excerpt(shared_story):
    """First few hundred characters of the shared story, tags stripped."""
    content = None
    if shared_story.story_content_z:
        try:
            content = smart_str(zlib.decompress(shared_story.story_content_z))
        except zlib.error:
            content = None
    if not content:
        content = shared_story.story_content
    if not content:
        return ""

    text = re.sub(r"\s+", " ", strip_tags(content)).strip()

    return text[:EXCERPT_LENGTH]


def _comment(shared_story):
    if not shared_story.has_comments or not shared_story.comments:
        return ""

    text = re.sub(r"\s+", " ", strip_tags(shared_story.comments)).strip()

    return text[:COMMENT_LENGTH]


def _candidate_score(candidate):
    """Rank candidates for the pool. A written comment is worth more than any amount of likes."""
    score = 0.0
    if candidate["comments"]:
        score += 2.0 + min(len(candidate["comments"]) / 200.0, 1.0)
    score += min(candidate["likes"] * 0.3, 1.5)
    score += min(candidate["replies"] * 0.2, 1.0)

    return score


def collect_candidates(hours=CANDIDATE_HOURS, pool_size=CANDIDATE_POOL_SIZE, now=None):
    """Gather recent shares worth considering, capped per sharer and deduped by story."""
    from apps.rss_feeds.models import Feed
    from apps.social.models import MSharedStory, MSocialProfile

    now = now or datetime.datetime.now()
    cutoff = now - datetime.timedelta(hours=hours)
    already_curated = RGlobalSharedStory.curated_story_hashes()

    # apps/social/curation.py: Only the fields the pool needs. A shared story also carries the
    # cached original page, which can run to megabytes and is useless here.
    shared_stories = (
        MSharedStory.objects(shared_date__gte=cutoff)
        .only(
            "user_id",
            "story_hash",
            "story_feed_id",
            "story_title",
            "story_date",
            "story_content",
            "story_content_z",
            "comments",
            "has_comments",
            "liking_users",
            "replies",
        )
        .order_by("-shared_date")
    )
    shared_stories = [story for story in shared_stories if story.story_hash not in already_curated]
    if not shared_stories:
        return []

    user_ids = list({story.user_id for story in shared_stories})
    profiles = MSocialProfile.objects(user_id__in=user_ids).only("user_id", "username", "private")
    usernames = {profile.user_id: profile.username for profile in profiles}
    private_user_ids = {profile.user_id for profile in profiles if profile.private}

    # apps/social/curation.py: @popular auto-shares the most-shared stories every ten minutes.
    # It is a bot, not a reader, so its shares carry no signal and would swamp the pool.
    popular_user_ids = set(User.objects.filter(username="popular").values_list("pk", flat=True))

    feed_ids = list({story.story_feed_id for story in shared_stories})
    allowed_feed_ids = set(Feed.exclude_briefing_feeds(feed_ids))
    feed_titles = dict(Feed.objects.filter(pk__in=list(allowed_feed_ids)).values_list("pk", "feed_title"))

    by_user = {}
    seen_story_hashes = set()
    for story in shared_stories:
        if story.user_id in private_user_ids or story.user_id in popular_user_ids:
            continue
        if story.story_feed_id not in allowed_feed_ids:
            continue
        if story.story_hash in seen_story_hashes:
            continue
        seen_story_hashes.add(story.story_hash)
        by_user.setdefault(story.user_id, []).append(
            {
                "story_hash": story.story_hash,
                "story_title": story.story_title or "",
                "story_date": story.story_date,
                "feed_title": feed_titles.get(story.story_feed_id) or "",
                "username": usernames.get(story.user_id) or "",
                "comments": _comment(story),
                "excerpt": _excerpt(story),
                "likes": len(story.liking_users or []),
                "replies": len(story.replies or []),
            }
        )

    candidates = []
    for user_candidates in by_user.values():
        user_candidates.sort(key=_candidate_score, reverse=True)
        candidates.extend(user_candidates[:MAX_SHARES_PER_USER])

    if len(candidates) <= pool_size:
        random.shuffle(candidates)
        return candidates

    # apps/social/curation.py: Sample from twice the pool size rather than taking a strict
    # top-N, so a quiet week of shares doesn't hand the model the same candidates every hour.
    candidates.sort(key=_candidate_score, reverse=True)
    shortlist = candidates[: pool_size * 2]

    return random.sample(shortlist, pool_size)


def _format_candidates(candidates):
    lines = []
    for index, candidate in enumerate(candidates):
        lines.append(f"[{index}] {candidate['story_title']}")
        lines.append(f"    Site: {candidate['feed_title']}")
        lines.append(f"    Shared by: {candidate['username']}")
        if candidate["comments"]:
            lines.append(f"    Their comment: {candidate['comments']}")
        if candidate["excerpt"]:
            lines.append(f"    Excerpt: {candidate['excerpt']}")
        lines.append("")

    return "\n".join(lines)


def parse_picks(response_text, candidate_count):
    """Pull pick ids out of the model's JSON, dropping anything malformed or out of range."""
    import json

    if not response_text:
        return []

    match = re.search(r"\{.*\}", response_text, re.DOTALL)
    if not match:
        return []

    try:
        parsed = json.loads(match.group(0))
    except ValueError:
        return []

    picks = []
    seen = set()
    for pick in parsed.get("picks") or []:
        if not isinstance(pick, dict):
            continue
        try:
            index = int(pick.get("id"))
        except (TypeError, ValueError):
            continue
        if index < 0 or index >= candidate_count or index in seen:
            continue
        seen.add(index)
        picks.append({"index": index, "reason": (pick.get("reason") or "")[:120]})

    return picks[:MAX_PICKS]


def select_with_llm(candidates, max_picks=MAX_PICKS):
    """Ask Haiku which candidates are worth the river. Returns None when the API is unusable."""
    from apps.ask_ai.providers import LLM_EXCEPTIONS, get_briefing_provider

    provider, model_id = get_briefing_provider("haiku")
    if not provider.is_configured():
        logging.debug(" ---> ~FRGlobal shared: ~FYAnthropic not configured, using fallback")
        return None

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {
            "role": "user",
            "content": (
                f"Here are {len(candidates)} stories shared on NewsBlur in the last few hours. "
                f"Pick at most {max_picks} of them, and fewer if fewer deserve it.\n\n"
                f"{_format_candidates(candidates)}"
            ),
        },
    ]

    try:
        response_text = provider.generate(messages, model_id, max_tokens=1024)
    except LLM_EXCEPTIONS as e:
        logging.debug(" ---> ~FRGlobal shared: ~FYHaiku failed (%s), using fallback" % e)
        return None

    input_tokens, output_tokens = provider.get_last_usage()
    LLMCostTracker.record_usage(
        provider="anthropic",
        model=model_id,
        feature="global_shared",
        input_tokens=input_tokens,
        output_tokens=output_tokens,
        metadata={"candidates": len(candidates)},
    )

    return parse_picks(response_text, len(candidates))


def select_by_heuristic(candidates, max_picks=MAX_PICKS):
    """Fallback selection: best-scoring shares, one per site, uncommented ones only as filler."""
    ordered = sorted(
        range(len(candidates)), key=lambda index: _candidate_score(candidates[index]), reverse=True
    )
    picks = []
    seen_feeds = set()
    uncommented = 0
    for index in ordered:
        candidate = candidates[index]
        if not candidate["comments"]:
            if uncommented >= max_picks // 2:
                continue
            uncommented += 1
        if candidate["feed_title"] in seen_feeds:
            continue
        seen_feeds.add(candidate["feed_title"])
        picks.append({"index": index, "reason": "fallback"})
        if len(picks) >= max_picks:
            break

    return picks


def curate_global_shared_stories(hours=CANDIDATE_HOURS, max_picks=MAX_PICKS, now=None):
    """Pick this hour's Global Shared Stories and add them to the river."""
    now = now or datetime.datetime.now()
    candidates = collect_candidates(hours=hours, now=now)
    RGlobalSharedStory.set_refreshed(now.timestamp())

    if not candidates:
        logging.debug(" ---> ~FBGlobal shared: no new shares to curate")
        return {"candidates": 0, "picked": 0, "added": 0, "used_llm": False}

    picks = select_with_llm(candidates, max_picks=max_picks)
    used_llm = picks is not None
    if not used_llm:
        picks = select_by_heuristic(candidates, max_picks=max_picks)

    story_dates = {}
    for pick in picks:
        candidate = candidates[pick["index"]]
        story_date = candidate["story_date"] or now
        story_dates[candidate["story_hash"]] = story_date.timestamp()

    added = RGlobalSharedStory.add_stories(story_dates)

    logging.debug(
        " ---> ~FBGlobal shared stories curated: ~SB%s~SN picked from ~SB%s~SN candidates (~SB%s~SN added, %s)"
        % (len(picks), len(candidates), added, "haiku" if used_llm else "fallback")
    )

    return {
        "candidates": len(candidates),
        "picked": len(picks),
        "added": added,
        "used_llm": used_llm,
    }
