from apps.rss_feeds.models import Feed, MStory
from apps.reader.models import UserSubscription
from apps.search.models import SearchStory
from utils import json_functions as json
from utils.view_functions import required_params
from utils.user_functions import get_user, ajax_login_required

# @required_params('story_hash')
@json.json_view
def more_like_this(request):
    user = get_user(request)
    get_post = getattr(request, request.method)
    order = get_post.get('order', 'newest')
    page = int(get_post.get('page', 1))
    limit = int(get_post.get('limit', 10))
    offset = limit * (page-1)
    story_hash = get_post.get('story_hash')
    
    feed_ids = [us.feed_id for us in UserSubscription.objects.filter(user=user)]
    feed_ids, _ = MStory.split_story_hash(story_hash)
    story_ids = SearchStory.more_like_this([feed_ids], story_hash, order, offset=offset, limit=limit)
    stories_db = MStory.objects(
        story_hash__in=story_ids
    ).order_by('-story_date' if order == "newest" else 'story_date')
    stories = Feed.format_stories(stories_db)

    return {
        "stories": stories,
    }
