"""Personalized discovery from public stories and account-owned reading signals."""

import datetime
import math
import re
import uuid
import zlib
from collections import Counter
from urllib.parse import parse_qsl, urlencode, urlsplit

import redis
from django.conf import settings
from django.core.cache import cache

from apps.reader.models import UserSubscription
from apps.recommendations.models import MRecommendationFeedback
from apps.rss_feeds.models import Feed, MStarredStory, MStory
from apps.social.models import MSharedStory
from apps.statistics.rtrending import RTrendingStory
from utils.story_functions import strip_tags


class Discovery:
    """Bounded lexical baseline; ranking never makes an external model call."""

    CANDIDATES_PER_LIST = 120
    HISTORY_LIMIT = 150
    SNAPSHOT_TTL = 60 * 60
    STOP_WORDS = set(
        "a an and are as at be been but by can could did do does for from had has have he her "
        "here him his how i if in into is it its just like more most my new no not of on one "
        "or our out she so some than that the their them there these they this those through "
        "to too up us was we were what when where which who will with would you your".split()
    )

    @staticmethod
    def url_identity(url):
        try:
            parsed = urlsplit(url or "")
            if parsed.scheme not in ("http", "https") or not parsed.hostname or parsed.username:
                return None
            # discovery.py: Keep meaningful query parameters while deduplicating tracking links.
            query = sorted(
                (k, v)
                for k, v in parse_qsl(parsed.query)
                if not k.lower().startswith("utm_") and k.lower() not in ("fbclid", "gclid")
            )
            return (
                parsed.netloc.lower().removeprefix("www.")
                + parsed.path.rstrip("/")
                + ("?" + urlencode(query) if query else "")
            )
        except ValueError:
            return None

    @classmethod
    def public_feed(cls, feed):
        return bool(
            feed
            and not feed.is_private_branch
            and not feed.is_newsletter
            and not feed.is_forbidden
            and cls.url_identity(feed.feed_address)
            and cls.url_identity(feed.feed_link)
            and not re.search(
                r"[?&](?:[^=]*(?:token|auth|secret|password|api.?key|email|private)[^=]*)=",
                feed.feed_address or "",
                re.I,
            )
        )

    @classmethod
    def eligible_stories(cls, user_id, hashes):
        stories = {
            s.story_hash: s
            for s in MStory.objects(story_hash__in=hashes).only(
                "story_hash",
                "story_feed_id",
                "story_permalink",
                "story_title",
                "story_tags",
                "story_content",
                "story_content_z",
                "original_text_z",
            )
        }
        subscriptions = list(UserSubscription.objects.filter(user_id=user_id).select_related("feed"))
        followed_ids = {s.feed_id for s in subscriptions}
        followed_sources = {
            identity
            for sub in subscriptions
            for url in (sub.feed.feed_address, sub.feed.feed_link)
            if (identity := cls.url_identity(url))
        }
        feeds = Feed.objects.in_bulk({s.story_feed_id for s in stories.values()})
        seen_urls = set()
        eligible = []
        for story_hash in hashes:
            story = stories.get(story_hash)
            if not story:
                continue
            feed = feeds.get(story.story_feed_id)
            if not cls.public_feed(feed) or feed.pk in followed_ids:
                continue
            if any(cls.url_identity(url) in followed_sources for url in (feed.feed_address, feed.feed_link)):
                continue
            identity = cls.url_identity(story.story_permalink)
            if not identity or identity in seen_urls:
                continue
            seen_urls.add(identity)
            eligible.append(story)
        return eligible

    @classmethod
    def candidate_hashes(cls):
        hashes = []
        for getter in (
            RTrendingStory.get_good_read_story_hashes,
            RTrendingStory.get_long_read_story_hashes,
            RTrendingStory.get_well_read_story_hashes,
        ):
            hashes.extend(getter(limit=cls.CANDIDATES_PER_LIST))
        return list(dict.fromkeys(hashes))

    @staticmethod
    def story_text(story):
        if isinstance(story, MStory):
            content = story.original_text_str
        elif story.original_text_z or story.story_content_z:
            content = zlib.decompress(story.original_text_z or story.story_content_z).decode(
                "utf-8", errors="replace"
            )
        else:
            content = story.story_content
        return " ".join(
            [story.story_title or ""] * 3 + list(story.story_tags or []) + [strip_tags(content or "")[:6000]]
        )

    @classmethod
    def reading_examples(cls, user_id):
        key = "discovery:profile:v1:%s" % user_id
        examples = cache.get(key)
        if examples is not None:
            return examples
        reader = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        history = RTrendingStory._decode_members(reader.lrange("lRS:%s" % user_id, 0, cls.HISTORY_LIMIT - 1))
        stats = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        pipe = stats.pipeline()
        for day_offset in range(RTrendingStory.TTL_DAYS):
            day = datetime.date.today() - datetime.timedelta(days=day_offset)
            for story_hash in history:
                pipe.zscore(
                    "%s:%s:%s"
                    % (RTrendingStory.USER_DURATION_PREFIX, day, RTrendingStory._story_shard(story_hash)),
                    RTrendingStory._story_user_member(story_hash, user_id),
                )
        durations = pipe.execute()
        weights = {}
        for i, duration in enumerate(durations):
            if duration and duration >= RTrendingStory.GOOD_READ_TIME_SECONDS:
                story_hash = history[i % len(history)]
                weights[story_hash] = max(weights.get(story_hash, 0), min(duration / 60.0, 2.0))
        stories = {s.story_hash: s for s in MStory.objects(story_hash__in=list(weights))}
        for model, date_field in ((MStarredStory, "starred_date"), (MSharedStory, "shared_date")):
            for story in model.objects(user_id=user_id).order_by("-" + date_field).limit(30):
                stories[story.story_hash] = story
                weights[story.story_hash] = max(weights.get(story.story_hash, 0), 2.0)
        examples = [
            (story_hash, cls.story_text(story), weights[story_hash]) for story_hash, story in stories.items()
        ]
        cache.set(key, examples, 300)
        return examples

    @classmethod
    def rank(cls, stories, examples, feedback):
        # discovery.py: Explicit votes override passive signals, including a save on a disliked story.
        examples = {story_hash: (text, weight) for story_hash, text, weight in examples}
        for vote in feedback:
            if vote.value:
                examples[vote.story_hash] = (
                    " ".join(
                        [vote.story_title or ""] * 3
                        + list(vote.story_tags or [])
                        + [vote.story_excerpt or ""]
                    ),
                    vote.value * 4.0,
                )
        documents = [cls.story_text(s) for s in stories] + [text for text, _ in examples.values()]
        counts = [
            Counter(w for w in re.findall(r"[^\W\d_]{3,}", text.lower()) if w not in cls.STOP_WORDS)
            for text in documents
        ]
        frequency = Counter(word for words in counts for word in words)
        vectors = []
        for words in counts:
            vector = {
                w: (1 + math.log(n)) * math.log(1 + len(counts) / frequency[w]) for w, n in words.items()
            }
            norm = math.sqrt(sum(n * n for n in vector.values())) or 1
            vectors.append({w: n / norm for w, n in vector.items()})
        profile = Counter()
        for vector, (_, weight) in zip(vectors[len(stories) :], examples.values()):
            for word, value in vector.items():
                profile[word] += value * weight
        scale = sum(abs(weight) for _, weight in examples.values()) or 1
        scored = []
        for index, (story, vector) in enumerate(zip(stories, vectors)):
            similarity = sum(value * profile[word] for word, value in vector.items()) / scale
            score = similarity + 0.02 / (1 + index / 12.0)
            scored.append((score, index, story))
        scored.sort(key=lambda entry: (-entry[0], entry[1]))
        # discovery.py: Interleave sources so one prolific site cannot fill the stream.
        result = []
        while scored:
            counts_by_feed = Counter()
            deferred = []
            for entry in scored:
                feed_id = entry[2].story_feed_id
                if counts_by_feed[feed_id] >= 2:
                    deferred.append(entry)
                    continue
                result.append(entry[2].story_hash)
                counts_by_feed[feed_id] += 1
                if sum(counts_by_feed.values()) == 12:
                    counts_by_feed.clear()
            scored = deferred
        return result

    @classmethod
    def page(cls, user_id, page=1, limit=12, read_filter="unread", snapshot=None):
        if page == 1:
            stories = cls.eligible_stories(user_id, cls.candidate_hashes())
            if read_filter == "unread":
                reader = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
                pipe = reader.pipeline()
                for story in stories:
                    pipe.sismember("RS:%s" % user_id, story.story_hash)
                stories = [s for s, is_read in zip(stories, pipe.execute()) if not is_read]
            votes = list(
                MRecommendationFeedback.objects(user_id=user_id, value__ne=0)
                .order_by("-updated_date")
                .limit(200)
            )
            hashes = cls.rank(stories, cls.reading_examples(user_id), votes)
            snapshot = uuid.uuid4().hex
            cache.set("discovery:snapshot:%s:%s" % (user_id, snapshot), hashes, cls.SNAPSHOT_TTL)
        else:
            if not snapshot or not re.fullmatch(r"[0-9a-f]{32}", snapshot):
                raise ValueError("Refresh Discovery to load more stories.")
            hashes = cache.get("discovery:snapshot:%s:%s" % (user_id, snapshot))
            if hashes is None:
                raise ValueError("Refresh Discovery to load more stories.")
        offset = (page - 1) * limit
        # discovery.py: Recheck access and subscriptions without reordering an in-progress session.
        eligible = cls.eligible_stories(user_id, hashes[offset : offset + limit])
        return [s.story_hash for s in eligible], snapshot
