"""Search tasks: index user subscriptions and feeds in Elasticsearch."""

import datetime
import json
import re

import redis
from django.conf import settings

from newsblur_web.celeryapp import app
from utils import log as logging


@app.task()
def IndexSubscriptionsForSearch(user_id):
    from apps.search.models import MUserSearch

    user_search = MUserSearch.get_user(user_id)
    user_search.index_subscriptions_for_search()


@app.task()
def IndexSubscriptionsForDiscover(user_id):
    from apps.search.models import MUserSearch

    user_search = MUserSearch.get_user(user_id)
    user_search.index_subscriptions_for_discover()


@app.task()
def IndexSubscriptionsChunkForSearch(feed_ids, user_id):
    logging.debug(" ---> Indexing: %s for %s" % (feed_ids, user_id))
    from apps.search.models import MUserSearch

    user_search = MUserSearch.get_user(user_id)
    user_search.index_subscriptions_chunk_for_search(feed_ids)


@app.task()
def IndexSubscriptionsChunkForDiscover(feed_ids, user_id):
    from apps.search.models import MUserSearch

    user_search = MUserSearch.get_user(user_id)
    user_search.index_subscriptions_chunk_for_discover(feed_ids)


@app.task()
def IndexFeedsForSearch(feed_ids, user_id):
    from apps.search.models import MUserSearch

    MUserSearch.index_feeds_for_search(feed_ids, user_id)


@app.task()
def FinishIndexSubscriptionsForSearch(results, user_id, start):
    logging.debug(" ---> Indexing finished for %s" % (user_id))
    from apps.search.models import MUserSearch

    user_search = MUserSearch.get_user(user_id)
    user_search.finish_index_subscriptions_for_search(start)


@app.task()
def FinishIndexSubscriptionsForDiscover(results, user_id, start, total):
    logging.debug(" ---> Indexing finished for %s" % (user_id))
    from apps.search.models import MUserSearch

    user_search = MUserSearch.get_user(user_id)
    user_search.finish_index_subscriptions_for_discover(start, total)


def _json_default(obj):
    if isinstance(obj, (datetime.datetime, datetime.date)):
        return obj.isoformat()
    raise TypeError(f"Object of type {type(obj).__name__} is not JSON serializable")


def _publish_global_search(username, search_id, event_type, extra=None):
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    payload = {"type": event_type, "search_id": search_id}
    if extra:
        payload.update(extra)
    r.publish(username, f"global_search:{json.dumps(payload, ensure_ascii=False, default=_json_default)}")


STOP_WORDS = {
    'a', 'an', 'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
    'of', 'with', 'by', 'from', 'as', 'is', 'was', 'are', 'were', 'been',
    'be', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would',
    'could', 'should', 'may', 'might', 'must', 'shall', 'can', 'need',
    'it', 'its', 'this', 'that', 'these', 'those', 'not', 'no', 'so',
}


def _story_matches_all_terms(story, query_terms):
    """Check that all query terms appear literally in story title + content."""
    text = (story.get("story_title", "") + " " + story.get("story_content", "")).lower()
    # Strip HTML tags for matching
    text = re.sub(r"<[^>]+>", " ", text)
    return all(term in text for term in query_terms)


def _format_and_publish_results(story_hashes_with_scores, username, search_id, chunk_index, total_chunks, search_type, sort_order="relevance", query=None):
    from apps.rss_feeds.models import Feed, MStory

    if not story_hashes_with_scores:
        _publish_global_search(username, search_id, "results", {
            "stories": [], "feeds": {},
            "chunk_index": chunk_index, "total_chunks": total_chunks,
        })
        return

    score_map = {h: s for h, s in story_hashes_with_scores}
    max_score = max(score_map.values()) or 1

    all_hashes = list(score_map.keys())
    mstories = MStory.objects(story_hash__in=all_hashes)
    stories = Feed.format_stories(mstories)

    # Post-filter: verify all query terms appear literally in story text
    if query and search_type == "keyword":
        query_terms = [t.lower() for t in query.split() if t.lower() not in STOP_WORDS]
        before_count = len(stories)
        stories = [s for s in stories if _story_matches_all_terms(s, query_terms)]
        if before_count != len(stories):
            logging.info(f" ---> ~FBPost-filter: {before_count} -> {len(stories)} (removed {before_count - len(stories)} false positives)")

    # Collect feed metadata
    feed_ids_found = set()
    for story in stories:
        feed_ids_found.add(story.get("story_feed_id"))

    feeds = {}
    for fid in feed_ids_found:
        try:
            feed = Feed.get_by_id(fid)
            if feed:
                feeds[fid] = {
                    "feed_title": feed.feed_title,
                    "feed_address": feed.feed_address,
                    "feed_link": feed.feed_link,
                    "favicon_color": feed.favicon_color or "505050",
                    "favicon_fade": feed.favicon_fade() or "505050",
                    "favicon_border": feed.favicon_border() or "505050",
                    "favicon_text_color": feed.favicon_text_color() or "white",
                    "favicon_url": feed.favicon_url,
                    "id": feed.pk,
                }
        except Exception:
            pass

    # Add search metadata to stories
    for story in stories:
        story_hash = story.get("story_hash", "")
        raw_score = score_map.get(story_hash, 0)
        story["search_score"] = round(raw_score / max_score, 4)
        story["search_type"] = search_type

    if sort_order == "date":
        stories.sort(key=lambda s: s.get("story_date", ""), reverse=True)
    else:
        stories.sort(key=lambda s: s.get("search_score", 0), reverse=True)

    if stories:
        logging.info(f" ---> ~FBPublishing ~SB{len(stories)}~SN {search_type} results. Top: {stories[0].get('story_title', '')[:60]}")

    _publish_global_search(username, search_id, "results", {
        "stories": stories,
        "feeds": feeds,
        "chunk_index": chunk_index,
        "total_chunks": total_chunks,
    })


@app.task(name="global-search-keyword", time_limit=120, soft_time_limit=110)
def GlobalSearchKeyword(user_id, username, search_id, query, feed_ids=None, sort_order="relevance", operator="AND"):
    from apps.search.models import SearchStory

    try:
        if feed_ids:
            results = SearchStory.query(feed_ids, query, order="newest", offset=0, limit=100)
        else:
            results = SearchStory.global_query(query, order="newest", offset=0, limit=100, operator=operator)
        scored = [(h, 1.0) for h in results]
        scope = f"{len(feed_ids)} feeds" if feed_ids else "all feeds"
        logging.info(f" ---> ~FBGlobal search keyword ({operator}): ~SB{len(scored)}~SN results for ~SB{query}~SN ({scope})")
        # Post-filter with exact terms only for AND mode (all words must appear literally)
        post_query = query if operator == "AND" else None
        _format_and_publish_results(scored, username, search_id, 0, 2, "keyword", sort_order, query=post_query)
    except Exception as e:
        logging.error(f" ***> ~FRGlobal search keyword error: {e}")
        import traceback
        logging.error(traceback.format_exc())
        _publish_global_search(username, search_id, "error", {"error": str(e)})


@app.task(name="global-search-vector", time_limit=120, soft_time_limit=110)
def GlobalSearchVector(user_id, username, search_id, query_vector, feed_ids=None, sort_order="relevance"):
    from apps.search.models import DiscoverStory

    try:
        if not query_vector:
            _publish_global_search(username, search_id, "results", {
                "stories": [], "feeds": {},
                "chunk_index": 1, "total_chunks": 2,
            })
            return

        kwargs = {"max_results": 100}
        if feed_ids:
            kwargs["feed_ids_to_include"] = feed_ids
        hits = DiscoverStory.vector_query(query_vector, **kwargs)
        all_scored = [(hit["_id"], hit["_score"]) for hit in hits]

        # Filter low-relevance. Cosine similarity + 1.0: 2.0=identical, 1.0=orthogonal
        min_score = 1.3
        scored = [(h, s) for h, s in all_scored if s >= min_score]
        scope = f"{len(feed_ids)} feeds" if feed_ids else "all feeds"
        logging.info(f" ---> ~FBGlobal search vector: ~SB{len(scored)}~SN/{len(all_scored)} results ({scope})")

        _format_and_publish_results(scored, username, search_id, 1, 2, "vector", sort_order)
    except Exception as e:
        logging.error(f" ***> ~FRGlobal search vector error: {e}")
        import traceback
        logging.error(traceback.format_exc())
        _publish_global_search(username, search_id, "error", {"error": str(e)})


@app.task(name="global-search-complete")
def GlobalSearchComplete(user_id, username, search_id):
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    payload = {
        "type": "complete",
        "search_id": search_id,
    }
    r.publish(username, f"global_search:{json.dumps(payload)}")
