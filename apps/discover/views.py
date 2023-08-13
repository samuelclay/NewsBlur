import time
from collections import defaultdict
from django.shortcuts import render
from apps.rss_feeds.models import Feed
from utils import json_functions as json
from utils.user_functions import ajax_login_required


@ajax_login_required
@json.json_view
def discover_feeds(request):
    user = request.user
    feed_ids = request.GET.getlist('feed_id') or request.GET.getlist('feed_id[]')
    feeds = Feed.objects.filter(pk__in=feed_ids)
    discover_feeds = defaultdict(dict)
    for feed in feeds:
        discover_feeds[feed.pk]["feed"] = feed.canonical(include_favicon=False)
        discover_feeds[feed.pk]["stories"] = feed.get_stories(limit=5)
    return {"discover_feeds": discover_feeds}
