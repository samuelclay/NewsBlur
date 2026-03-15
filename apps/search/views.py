"""Search views: full-text story search and feed discovery via Elasticsearch."""

from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed, MStory
from apps.search.models import SearchStory  # noqa: F401
from utils import json_functions as json
from utils import log as logging
from utils.user_functions import ajax_login_required, get_user
from utils.view_functions import required_params


# @required_params('story_hash')
@json.json_view
def more_like_this(request):
    user = get_user(request)
    get_post = getattr(request, request.method)
    order = get_post.get("order", "newest")
    page = int(get_post.get("page", 1))
    limit = int(get_post.get("limit", 10))
    offset = limit * (page - 1)
    story_hash = get_post.get("story_hash")

    feed_ids = [us.feed_id for us in UserSubscription.objects.filter(user=user)]
    feed_ids, _ = MStory.split_story_hash(story_hash)
    story_ids = SearchStory.more_like_this([feed_ids], story_hash, order, offset=offset, limit=limit)
    stories_db = MStory.objects(story_hash__in=story_ids).order_by(
        "-story_date" if order == "newest" else "story_date"
    )
    stories = Feed.format_stories(stories_db)

    return {
        "stories": stories,
    }


@ajax_login_required
@json.json_view
def global_search(request):
    user = get_user(request)
    if not user.profile.is_pro:
        return {"code": -1, "message": "Global Search requires a Premium Pro subscription"}

    query = request.POST.get("query", "").strip()
    search_id = request.POST.get("search_id", "")
    feed_scope = request.POST.get("feed_scope", "global")  # "global" or "yours"
    search_type = request.POST.get("search_type", "all_words")  # "all_words", "any_word", or "semantic"
    sort_order = request.POST.get("sort_order", "relevance")  # "relevance" or "date"
    if not query or len(query) < 2:
        return {"code": -1, "message": "Query too short"}

    from celery import chord

    from apps.search.tasks import GlobalSearchComplete, GlobalSearchKeyword, GlobalSearchVector

    # Build feed_ids for "yours" scope
    feed_ids = None
    if feed_scope == "yours":
        feed_ids = [us.feed_id for us in UserSubscription.objects.filter(user=user).only("feed")]
        if not feed_ids:
            return {"code": -1, "message": "No subscriptions to search"}

    # Build task list based on options
    tasks = []
    chunk_count = 0

    if search_type == "semantic":
        # Semantic: vector search only (no keyword filtering)
        from apps.search.models import DiscoverStory

        query_vector = DiscoverStory.generate_query_vector(query)
        tasks.append(GlobalSearchVector.s(user.pk, user.username, search_id, query_vector, feed_ids, sort_order))
        chunk_count += 1
    else:
        # all_words or any_word: keyword search with operator
        operator = "AND" if search_type == "all_words" else "OR"
        tasks.append(
            GlobalSearchKeyword.s(user.pk, user.username, search_id, query, feed_ids, sort_order, operator)
        )
        chunk_count += 1

    chord(tasks)(GlobalSearchComplete.si(user.pk, user.username, search_id))

    # Get cached total feed count
    from django.core.cache import cache

    if feed_scope == "yours":
        total_feed_count = len(feed_ids)
    else:
        total_feed_count = cache.get("global_search:feed_count")
        if total_feed_count is None:
            total_feed_count = Feed.objects.filter(active_subscribers__gte=1).count()
            cache.set("global_search:feed_count", total_feed_count, 60 * 60)  # 1 hour

    logging.user(
        user,
        "~FBGlobal search: ~SB%s~SN (%s, %s)" % (query, feed_scope, search_type),
    )

    return {"code": 1, "search_id": search_id, "total_chunks": chunk_count, "total_feeds": total_feed_count}
