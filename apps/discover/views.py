"""
Discovery and search endpoints for finding and adding feeds.
Includes trending sites, YouTube/Reddit/Podcast search, newsletter conversion, etc.
"""
import re
from collections import defaultdict
from urllib.parse import urlparse, quote_plus

import requests
from django.conf import settings
from django.db.models import Count

from django.db.models import Q

from apps.discover.models import PopularFeed
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed, MFeedIcon, MStory
from apps.search.models import MUserSearch, SearchFeed
from apps.statistics.rtrending_subscriptions import RTrendingSubscription
from utils import json_functions as json
from utils import log as logging
from utils.user_functions import ajax_login_required


IGNORE_AUTOCOMPLETE = [
    "facebook.com/feeds/notifications.php",
    "inbox",
    "secret",
    "password",
    "latitude",
]


@ajax_login_required
@json.json_view
def search_feed(request):
    """Search for a single feed by URL/address."""
    address = request.GET.get("address")
    offset = int(request.GET.get("offset", 0))
    if not address:
        return dict(code=-1, message="Please provide a URL/address.")

    logging.user(request.user, "~FBFinding feed (search_feed): %s" % address)
    ip = request.META.get("HTTP_X_FORWARDED_FOR", None) or request.META["REMOTE_ADDR"]
    logging.user(request.user, "~FBIP: %s" % ip)
    aggressive = request.user.is_authenticated
    feed = Feed.get_feed_from_url(address, create=False, aggressive=aggressive, offset=offset)
    if feed:
        return feed.canonical()
    else:
        return dict(code=-1, message="No feed found matching that XML or website address.")


@json.json_view
def feed_autocomplete(request):
    """Autocomplete search for feeds by name or URL."""
    query = request.GET.get("term") or request.GET.get("query")
    version = int(request.GET.get("v", 1))
    autocomplete_format = request.GET.get("format", "autocomplete")
    include_stories = request.GET.get("include_stories", "false").lower() == "true"

    if not query:
        return dict(code=-1, message="Specify a search 'term'.", feeds=[], term=query)

    if "." in query:
        try:
            parts = urlparse(query)
            if not parts.hostname and not query.startswith("http"):
                parts = urlparse("http://%s" % query)
            if parts.hostname:
                query = [parts.hostname]
                query.extend([p for p in parts.path.split("/") if p])
                query = " ".join(query)
        except Exception:
            logging.user(request, "~FGAdd search, could not parse url in ~FR%s" % query)

    query_params = query.split(" ")
    tries_left = 5
    feed_ids = []
    while len(query_params) and tries_left:
        tries_left -= 1
        # Use higher limit (20) to include semantic matches alongside exact matches
        feed_ids = Feed.autocomplete(" ".join(query_params), limit=20)
        if feed_ids:
            break
        else:
            query_params = query_params[:-1]

    # Fallback to database search if Elasticsearch returns no results
    if not feed_ids:
        from django.db.models import Q

        search_query = query.split()[0] if query.split() else query
        db_feeds = Feed.objects.filter(
            Q(feed_title__icontains=search_query) | Q(feed_address__icontains=search_query)
        ).exclude(num_subscribers__lte=0).order_by("-num_subscribers")[:20]
        feed_ids = [f.pk for f in db_feeds]

    feeds = list(set([Feed.get_by_id(feed_id) for feed_id in feed_ids]))
    feeds = [feed for feed in feeds if feed and not feed.branch_from_feed]
    feeds = [feed for feed in feeds if all([x not in feed.feed_address for x in IGNORE_AUTOCOMPLETE])]

    if autocomplete_format == "autocomplete":
        feeds = [
            {
                "id": feed.pk,
                "value": feed.feed_address,
                "label": feed.feed_title,
                "tagline": feed.data and feed.data.feed_tagline,
                "num_subscribers": feed.num_subscribers,
                "last_story_date": feed.last_story_date.isoformat() if feed.last_story_date else None,
            }
            for feed in feeds
        ]
    else:
        feeds = [feed.canonical(full=True) for feed in feeds]
    feeds = sorted(feeds, key=lambda f: -1 * f["num_subscribers"])

    feed_ids = [f["id"] for f in feeds]
    feed_icons = dict((icon.feed_id, icon) for icon in MFeedIcon.objects.filter(feed_id__in=feed_ids))

    for feed in feeds:
        if feed["id"] in feed_icons:
            feed_icon = feed_icons[feed["id"]]
            if feed_icon.data:
                feed["favicon_color"] = feed_icon.color
                feed["favicon"] = feed_icon.data

    # Include stories for each feed if requested (for list view)
    if include_stories:
        feed_objects = {f.pk: f for f in [Feed.get_by_id(fid) for fid in feed_ids] if f}
        for feed_data in feeds:
            feed_obj = feed_objects.get(feed_data["id"])
            if feed_obj:
                feed_data["stories"] = feed_obj.get_stories(limit=5)
            else:
                feed_data["stories"] = []

    logging.user(
        request,
        "~FGAdd Search: ~SB%s ~SN(%s matches)"
        % (
            query,
            len(feeds),
        ),
    )

    if version > 1:
        return {
            "feeds": feeds,
            "term": query,
        }
    else:
        return feeds


@ajax_login_required
@json.json_view
def discover_feeds(request, feed_id=None):
    """Find similar feeds based on content vectors."""
    page = int(request.GET.get("page") or request.POST.get("page") or 1)
    limit = 5
    offset = (page - 1) * limit

    if request.method == "GET" and feed_id:
        similar_feed_ids = list(
            Feed.get_by_id(feed_id)
            .count_similar_feeds(force=True, offset=offset, limit=limit)
            .values_list("pk", flat=True)
        )
    elif request.method == "POST":
        feed_ids = request.POST.getlist("feed_ids")
        similar_feeds = Feed.find_similar_feeds(feed_ids=feed_ids, offset=offset, limit=limit)
        similar_feed_ids = [result["_source"]["feed_id"] for result in similar_feeds]
    else:
        return {"code": -1, "message": "Missing feed_ids.", "discover_feeds": None, "failed": True}

    feeds = Feed.objects.filter(pk__in=similar_feed_ids)
    discover_feeds = defaultdict(dict)
    for feed in feeds:
        discover_feeds[feed.pk]["feed"] = feed.canonical(include_favicon=False, full=True)
        discover_feeds[feed.pk]["stories"] = feed.get_stories(limit=5)

    logging.user(request, "~FCDiscovering similar feeds, page %s: ~SB%s" % (page, similar_feed_ids))
    return {"discover_feeds": discover_feeds}


@ajax_login_required
@json.json_view
def discover_stories(request, story_hash):
    """Find similar stories across feeds."""
    page = int(request.GET.get("page") or request.POST.get("page") or 1)
    feed_ids = request.GET.getlist("feed_ids") or request.POST.getlist("feed_ids")
    limit = 5
    offset = (page - 1) * limit
    story, _ = MStory.find_story(story_hash=story_hash)
    if not story:
        return {"code": -1, "message": "Story not found.", "discover_stories": None, "failed": True}

    user_search = MUserSearch.get_user(request.user.pk)
    user_search.touch_discover_date()

    similar_stories = story.fetch_similar_stories(feed_ids=feed_ids, offset=offset, limit=limit)
    similar_story_hashes = [result["_id"] for result in similar_stories]
    stories = MStory.objects.filter(story_hash__in=similar_story_hashes)
    stories = Feed.format_stories(stories)

    # Find unsubscribed feeds
    subscribed_feed_ids = UserSubscription.objects.filter(
        user=request.user, feed_id__in=set(story["story_feed_id"] for story in stories)
    ).values_list("feed_id", flat=True)
    feeds = Feed.objects.filter(
        pk__in=set(story["story_feed_id"] for story in stories) - set(subscribed_feed_ids)
    )
    feeds = {feed.pk: feed.canonical(include_favicon=False) for feed in feeds}

    return {"discover_stories": stories, "feeds": feeds}


@json.json_view
def trending_sites(request):
    """
    Returns trending feeds with their recent stories for the Trending Sites feature.
    Uses subscription velocity from RTrendingSubscription to determine trending feeds.
    Falls back to popular feeds by subscriber count when no trending data exists.
    """
    page = int(request.GET.get("page", 1))
    days = int(request.GET.get("days", 7))
    limit = 20
    offset = (page - 1) * limit

    # Validate days parameter
    if days not in [1, 7, 30]:
        days = 7

    # Get trending feed IDs from subscription velocity
    # In DEBUG mode, use min_subscribers=1 to show results with limited data
    min_subs = 1 if settings.DEBUG else RTrendingSubscription.MIN_SUBSCRIBERS_THRESHOLD
    trending_data = RTrendingSubscription.get_trending_feeds(
        days=days,
        limit=limit + offset + 10,  # Get extra to account for filtering
        min_subscribers=min_subs,
    )

    # Slice for pagination
    trending_feed_ids = [int(feed_id) for feed_id, score in trending_data[offset : offset + limit]]

    # Fallback: if no trending data, return popular feeds by subscriber count
    use_fallback = False
    if not trending_feed_ids:
        use_fallback = True
        popular_feeds = Feed.objects.filter(
            num_subscribers__gte=10,
            is_push=False,
        ).order_by("-num_subscribers")[offset : offset + limit + 1]
        trending_feed_ids = [f.pk for f in popular_feeds[:limit]]
        # Create fake trending_data for score lookup
        trending_data = [(fid, 1) for fid in trending_feed_ids]

    if not trending_feed_ids:
        return {"trending_feeds": {}, "has_more": False}

    # Build response with feed details and stories
    feeds = Feed.objects.filter(pk__in=trending_feed_ids)
    feeds_dict = {feed.pk: feed for feed in feeds}

    # Build ordered response preserving trending order
    trending_feeds = {}
    for feed_id in trending_feed_ids:
        if feed_id in feeds_dict:
            feed = feeds_dict[feed_id]
            # Find score for this feed (use subscriber count for fallback)
            if use_fallback:
                score = feed.num_subscribers
            else:
                score = next((s for fid, s in trending_data if int(fid) == feed_id), 0)
            trending_feeds[feed_id] = {
                "feed": feed.canonical(include_favicon=False, full=True),
                "stories": feed.get_stories(limit=5),
                "trending_score": score,
            }

    if use_fallback:
        has_more = len(trending_feed_ids) > limit
    else:
        has_more = len(trending_data) > offset + limit

    logging.user(request, "~FCTrending sites (page %s, %sd): ~SB%s feeds%s" % (page, days, len(trending_feeds), " (fallback)" if use_fallback else ""))
    return {"trending_feeds": trending_feeds, "has_more": has_more}


@json.json_view
def youtube_search(request):
    """
    Search YouTube channels and playlists using the YouTube Data API v3.
    Returns results with constructed RSS feed URLs.
    """
    query = request.GET.get("query", "").strip()
    search_type = request.GET.get("type", "channel")  # 'channel' or 'playlist'
    max_results = min(int(request.GET.get("limit", 10)), 25)

    if not query:
        return {"code": -1, "message": "Please provide a search query.", "results": []}

    if not settings.YOUTUBE_API_KEY or settings.YOUTUBE_API_KEY == "YOUR_YOUTUBE_API_KEY":
        return {"code": -1, "message": "YouTube API key not configured.", "results": []}

    # Build YouTube Data API v3 search URL
    api_url = "https://www.googleapis.com/youtube/v3/search"
    params = {
        "part": "snippet",
        "q": query,
        "type": search_type,
        "maxResults": max_results,
        "key": settings.YOUTUBE_API_KEY,
    }

    try:
        response = requests.get(api_url, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
    except requests.exceptions.RequestException as e:
        logging.user(request, "~FRYouTube search error: %s" % str(e))
        return {"code": -1, "message": "YouTube API request failed.", "results": []}

    if "error" in data:
        error_msg = data["error"].get("message", "Unknown error")
        logging.user(request, "~FRYouTube API error: %s" % error_msg)
        return {"code": -1, "message": error_msg, "results": []}

    results = []
    for item in data.get("items", []):
        snippet = item.get("snippet", {})
        thumbnails = snippet.get("thumbnails", {})
        thumbnail_url = thumbnails.get("medium", {}).get("url") or thumbnails.get("default", {}).get("url", "")

        if search_type == "channel":
            channel_id = item.get("id", {}).get("channelId")
            if channel_id:
                feed_url = f"https://www.youtube.com/feeds/videos.xml?channel_id={channel_id}"
                channel_url = f"https://www.youtube.com/channel/{channel_id}"
                results.append({
                    "id": channel_id,
                    "type": "channel",
                    "title": snippet.get("channelTitle") or snippet.get("title", ""),
                    "description": snippet.get("description", ""),
                    "thumbnail": thumbnail_url,
                    "feed_url": feed_url,
                    "link": channel_url,
                })
        elif search_type == "playlist":
            playlist_id = item.get("id", {}).get("playlistId")
            if playlist_id:
                feed_url = f"https://www.youtube.com/feeds/videos.xml?playlist_id={playlist_id}"
                playlist_url = f"https://www.youtube.com/playlist?list={playlist_id}"
                results.append({
                    "id": playlist_id,
                    "type": "playlist",
                    "title": snippet.get("title", ""),
                    "description": snippet.get("description", ""),
                    "thumbnail": thumbnail_url,
                    "feed_url": feed_url,
                    "link": playlist_url,
                    "channel_title": snippet.get("channelTitle", ""),
                })

    logging.user(request, "~FBYouTube search for '%s' (%s): ~SB%s results" % (query, search_type, len(results)))
    return {"code": 1, "results": results}


@json.json_view
def reddit_search(request):
    """
    Search Reddit subreddits using the public Reddit JSON API.
    Returns results with constructed RSS feed URLs.
    """
    query = request.GET.get("query", "").strip()
    limit = min(int(request.GET.get("limit", 15)), 25)

    if not query:
        return {"code": -1, "message": "Please provide a search query.", "results": []}

    # Reddit's public JSON API for subreddit search
    api_url = "https://www.reddit.com/subreddits/search.json"
    params = {
        "q": query,
        "limit": limit,
        "include_over_18": "false",
    }
    headers = {
        "User-Agent": "NewsBlur/1.0 (RSS Reader; https://newsblur.com)",
    }

    try:
        response = requests.get(api_url, params=params, headers=headers, timeout=10)
        response.raise_for_status()
        data = response.json()
    except requests.exceptions.RequestException as e:
        logging.user(request, "~FRReddit search error: %s" % str(e))
        return {"code": -1, "message": "Reddit API request failed.", "results": []}

    results = []
    for child in data.get("data", {}).get("children", []):
        subreddit = child.get("data", {})
        name = subreddit.get("display_name", "")
        if name:
            feed_url = f"https://www.reddit.com/r/{name}/.rss"
            subreddit_url = f"https://www.reddit.com/r/{name}"

            # Get icon - try community_icon first, then icon_img
            icon_url = subreddit.get("community_icon", "")
            if icon_url:
                # Remove query params that may cause issues
                icon_url = icon_url.split("?")[0]
            if not icon_url:
                icon_url = subreddit.get("icon_img", "")

            results.append({
                "id": subreddit.get("id", ""),
                "name": name,
                "title": subreddit.get("title", name),
                "description": subreddit.get("public_description", "")[:200],
                "subscribers": subreddit.get("subscribers", 0),
                "icon": icon_url,
                "feed_url": feed_url,
                "link": subreddit_url,
                "over18": subreddit.get("over18", False),
            })

    logging.user(request, "~FBReddit search for '%s': ~SB%s results" % (query, len(results)))
    return {"code": 1, "results": results}


@json.json_view
def reddit_popular(request):
    """
    Get popular Reddit subreddits.
    Returns results with constructed RSS feed URLs.
    """
    limit = min(int(request.GET.get("limit", 20)), 50)

    # Reddit's public JSON API for popular subreddits
    api_url = "https://www.reddit.com/subreddits/popular.json"
    params = {
        "limit": limit,
    }
    headers = {
        "User-Agent": "NewsBlur/1.0 (RSS Reader; https://newsblur.com)",
    }

    try:
        response = requests.get(api_url, params=params, headers=headers, timeout=10)
        response.raise_for_status()
        data = response.json()
    except requests.exceptions.RequestException as e:
        logging.user(request, "~FRReddit popular error: %s" % str(e))
        return {"code": -1, "message": "Reddit API request failed.", "results": []}

    results = []
    for child in data.get("data", {}).get("children", []):
        subreddit = child.get("data", {})
        name = subreddit.get("display_name", "")
        if name and not subreddit.get("over18", False):
            feed_url = f"https://www.reddit.com/r/{name}/.rss"
            subreddit_url = f"https://www.reddit.com/r/{name}"

            # Get icon - try community_icon first, then icon_img
            icon_url = subreddit.get("community_icon", "")
            if icon_url:
                icon_url = icon_url.split("?")[0]
            if not icon_url:
                icon_url = subreddit.get("icon_img", "")

            results.append({
                "id": subreddit.get("id", ""),
                "name": name,
                "title": subreddit.get("title", name),
                "description": subreddit.get("public_description", "")[:200],
                "subscribers": subreddit.get("subscribers", 0),
                "icon": icon_url,
                "feed_url": feed_url,
                "link": subreddit_url,
            })

    logging.user(request, "~FBReddit popular: ~SB%s results" % len(results))
    return {"code": 1, "results": results}


@json.json_view
def newsletter_convert(request):
    """
    Convert a newsletter URL to its RSS feed URL.
    Supports Substack, Medium, Ghost, and other common platforms.
    """
    url = request.GET.get("url", "").strip()

    if not url:
        return {"code": -1, "message": "Please provide a newsletter URL.", "feed_url": None}

    # Normalize URL
    if not url.startswith(("http://", "https://")):
        url = "https://" + url

    # Remove trailing slash
    url = url.rstrip("/")

    feed_url = None
    platform = None
    title = None

    # Parse the URL
    parsed = urlparse(url)
    hostname = parsed.netloc.lower()
    path = parsed.path

    # Substack detection
    if "substack.com" in hostname or hostname.endswith(".substack.com"):
        # Extract subdomain for substack
        if hostname.endswith(".substack.com"):
            subdomain = hostname.replace(".substack.com", "")
            feed_url = f"https://{subdomain}.substack.com/feed"
            title = subdomain.replace("-", " ").title()
        else:
            # Could be a custom domain pointing to substack
            feed_url = f"{url}/feed"
        platform = "substack"

    # Medium detection
    elif "medium.com" in hostname:
        if path.startswith("/@"):
            # User profile: medium.com/@username
            username = path.split("/")[1]
            feed_url = f"https://medium.com/feed/{username}"
            title = username.lstrip("@")
        elif path.startswith("/"):
            # Publication: medium.com/publication-name
            publication = path.split("/")[1] if len(path.split("/")) > 1 else ""
            if publication and publication != "":
                feed_url = f"https://medium.com/feed/{publication}"
                title = publication.replace("-", " ").title()
        platform = "medium"

    # Ghost blogs (common pattern)
    elif any(ghost_indicator in url.lower() for ghost_indicator in [".ghost.io", "/ghost/"]):
        feed_url = f"{url}/rss/"
        platform = "ghost"

    # Buttondown detection
    elif "buttondown.email" in hostname:
        # buttondown.email/username
        username = path.lstrip("/").split("/")[0] if path else ""
        if username:
            feed_url = f"https://buttondown.email/{username}/rss"
            title = username.replace("-", " ").title()
        platform = "buttondown"

    # Beehiiv detection
    elif ".beehiiv.com" in hostname:
        feed_url = f"{url}/feed"
        platform = "beehiiv"

    # ConvertKit detection
    elif "convertkit.com" in hostname or ".ck.page" in hostname:
        # ConvertKit doesn't have standard RSS - try /rss
        feed_url = f"{url}/rss"
        platform = "convertkit"

    # Revue (Twitter newsletters - now defunct but some archives exist)
    elif "revue.co" in hostname or "getrevue.co" in hostname:
        username = path.lstrip("/").split("/")[0] if path else ""
        if username:
            feed_url = f"https://www.getrevue.co/profile/{username}/feed"
            title = username.replace("-", " ").title()
        platform = "revue"

    # Generic fallback - try common RSS patterns
    else:
        # Try to detect if it's already a feed URL
        if any(ext in url.lower() for ext in ["/feed", "/rss", ".xml", "/atom"]):
            feed_url = url
            platform = "direct"
        else:
            # Try adding /feed (most common pattern)
            feed_url = f"{url}/feed"
            platform = "generic"

    if not feed_url:
        return {"code": -1, "message": "Could not determine RSS feed URL.", "feed_url": None}

    logging.user(request, "~FBNewsletter convert: %s -> %s (%s)" % (url, feed_url, platform))
    return {
        "code": 1,
        "feed_url": feed_url,
        "platform": platform,
        "title": title,
        "original_url": url,
    }


@json.json_view
def podcast_search(request):
    """
    Search for podcasts using iTunes Search API.
    Returns podcasts with their RSS feed URLs.
    """
    query = request.GET.get("query", "").strip()
    limit = min(int(request.GET.get("limit", 20)), 50)

    if not query:
        return {"code": -1, "message": "Query is required", "results": []}

    # iTunes Search API (free, no auth required)
    api_url = "https://itunes.apple.com/search"
    params = {
        "term": query,
        "media": "podcast",
        "limit": limit,
        "entity": "podcast",
    }

    try:
        headers = {"User-Agent": "NewsBlur/1.0 (RSS Reader; https://newsblur.com)"}
        response = requests.get(api_url, params=params, headers=headers, timeout=10)
        response.raise_for_status()
        data = response.json()

        results = []
        for podcast in data.get("results", []):
            # Only include podcasts that have a feed URL
            feed_url = podcast.get("feedUrl")
            if not feed_url:
                continue

            results.append({
                "name": podcast.get("collectionName", ""),
                "artist": podcast.get("artistName", ""),
                "artwork": podcast.get("artworkUrl100", ""),
                "feed_url": feed_url,
                "genre": podcast.get("primaryGenreName", ""),
                "track_count": podcast.get("trackCount", 0),
                "itunes_url": podcast.get("collectionViewUrl", ""),
            })

        logging.user(request, "~FBPodcast search for '%s': %s results" % (query, len(results)))
        return {"code": 1, "results": results, "query": query}

    except requests.exceptions.RequestException as e:
        logging.user(request, "~FRPodcast search error: %s" % str(e))
        return {"code": -1, "message": "Failed to search podcasts", "results": []}


@json.json_view
def google_news_feed(request):
    """
    Build a Google News RSS feed URL from search parameters.
    Returns the constructed RSS URL for subscribing.
    Supports both custom search queries and predefined topic feeds.
    """
    query = request.GET.get("query", "").strip()
    topic = request.GET.get("topic", "").strip().upper()
    language = request.GET.get("language", "en")
    region = request.GET.get("region", "US")

    # Topic map for predefined Google News topics
    topic_map = {
        "WORLD": "CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx1YlY4U0FtVnVHZ0pWVXlnQVAB",
        "NATION": "CAAqIggKIhxDQkFTRHdvSkwyMHZNRFY2TVdZeUVnSmxiaWdBUAE",
        "BUSINESS": "CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx6TVdZU0FtVnVHZ0pWVXlnQVAB",
        "TECHNOLOGY": "CAAqJggKIiBDQkFTRWdvSUwyMHZNRGRqTVhZU0FtVnVHZ0pWVXlnQVAB",
        "ENTERTAINMENT": "CAAqJggKIiBDQkFTRWdvSUwyMHZNREpxYW5RU0FtVnVHZ0pWVXlnQVAB",
        "SPORTS": "CAAqJggKIiBDQkFTRWdvSUwyMHZNRFp1ZEdvU0FtVnVHZ0pWVXlnQVAB",
        "SCIENCE": "CAAqJggKIiBDQkFTRWdvSUwyMHZNRFp0Y1RjU0FtVnVHZ0pWVXlnQVAB",
        "HEALTH": "CAAqIQgKIhtDQkFTRGdvSUwyMHZNR3QwTlRFU0FtVnVLQUFQAQ",
    }

    # Build feed URL based on topic or custom query
    if topic and topic in topic_map:
        # Topic-based feed
        feed_url = f"https://news.google.com/rss/topics/{topic_map[topic]}?hl={language}&gl={region}&ceid={region}:{language}"
        title = f"Google News - {topic.title()}"
    elif query:
        # Custom search query feed
        encoded_query = quote_plus(query)
        feed_url = f"https://news.google.com/rss/search?q={encoded_query}&hl={language}&gl={region}&ceid={region}:{language}"
        title = f"Google News - {query}"
    else:
        return {"code": -1, "message": "Search query or topic is required", "feed_url": None}

    logging.user(request, "~FBGoogle News feed built: %s" % feed_url)
    return {
        "code": 1,
        "feed_url": feed_url,
        "title": title,
        "query": query,
        "topic": topic,
        "language": language,
        "region": region,
    }


@json.json_view
def popular_channels(request):
    """
    Returns pre-seeded popular channels (YouTube, Newsletters, Podcasts) with stories.
    Used by Add Site view in list mode to show recent stories for each feed.
    Feeds must be pre-created using the bootstrap_popular_channels management command.
    """
    channel_type = request.GET.get("type", "all")  # youtube, newsletters, podcasts, all
    limit = min(int(request.GET.get("limit", 20)), 50)

    # URLs mirroring add_site_view.js - must match bootstrap_popular_channels.py
    POPULAR_YOUTUBE_URLS = [
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCBcRF18a7Qf58cCRy5xuWwQ",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCXuqSBlHAE6Xw-yeJA0Tunw",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UC6nSFpj9HTCZ5t-N3Rm3-HA",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCsXVk37bltHxD1rDPwtNM8Q",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCHnyfMqiRRG1u-2MsSQLbXA",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCWX3bGDLdJ8y_E7n2ghDbTQ",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UC9-y-6csu5WGm29I7JiwpnA",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCy0tKL1T7wFoYcxCe0xjN6Q",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCVHFbqXqoYvEWM1Ddxl0QKg",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCeY0bbntWzzVIaj2z3QigXg",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCupvZG-5ko_eiXAupbDfxWw",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCYfdidRxbB8Qhf0Nx7ioOYw",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCddiUEpeqJcYeBxX1IVBKvQ",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCBJycsmduvYEL83R_U4JriQ",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCVls1GmFKf6WlTraIb_IaJg",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCX6OQ3DkcsbYNE6H8uQQuVA",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UC-lHJZR3Gqxm24_Vd_AJ5Yw",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCq-Fj5jknLsUf-MWSy4_brA",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCYO_jab_esuFRV4b17AJtAw",
        "https://www.youtube.com/feeds/videos.xml?channel_id=UC2C_jShtL725hvbm1arSV9w",
    ]

    POPULAR_NEWSLETTER_URLS = [
        "https://thehustle.co/feed/",
        "https://www.lennysnewsletter.com/feed",
        "https://stratechery.com/feed/",
        "https://newsletter.pragmaticengineer.com/feed",
        "https://www.platformer.news/feed",
        "https://www.bloomberg.com/opinion/authors/ARbTQlRLRjE/matthew-s-levine.rss",
        "https://towardsdatascience.com/feed",
        "https://betterprogramming.pub/feed",
        "https://onezero.medium.com/feed",
        "https://css-tricks.com/feed/",
        "https://www.smashingmagazine.com/feed/",
        "https://www.morningbrew.com/daily/rss",
        "https://www.theverge.com/rss/index.xml",
        "https://feeds.arstechnica.com/arstechnica/index",
        "https://news.ycombinator.com/rss",
    ]

    POPULAR_PODCAST_URLS = [
        "https://feeds.simplecast.com/54nAGcIl",
        "https://feeds.simplecast.com/xl36XBC2",
        "https://www.thisamericanlife.org/podcast/rss.xml",
        "https://feeds.simplecast.com/EmVW7VGp",
        "https://feeds.npr.org/510289/podcast.xml",
        "https://feeds.npr.org/510313/podcast.xml",
        "https://feeds.simplecast.com/Y8lFbOT4",
        "https://feeds.simplecast.com/JBiZ0WnY",
        "https://lexfridman.com/feed/podcast/",
        "https://feeds.simplecast.com/4MVDEgRM",
        "https://feeds.megaphone.fm/vergecast",
        "https://feeds.simplecast.com/dHoohVNH",
        "https://feeds.simplecast.com/xs0YcAjq",
        "https://feeds.megaphone.fm/stuffyoushouldknow",
        "https://feeds.npr.org/510308/podcast.xml",
        "https://feeds.simplecast.com/qm_9xx0g",
        "https://feeds.simplecast.com/GLTi1Mcb",
        "https://feeds.npr.org/510298/podcast.xml",
        "https://feeds.megaphone.fm/GLT1412515089",
        "https://feeds.feedburner.com/dancarlin/history",
    ]

    # Collect URLs based on requested type
    urls = []
    if channel_type in ("youtube", "all"):
        urls.extend(POPULAR_YOUTUBE_URLS)
    if channel_type in ("newsletters", "all"):
        urls.extend(POPULAR_NEWSLETTER_URLS)
    if channel_type in ("podcasts", "all"):
        urls.extend(POPULAR_PODCAST_URLS)

    # Fetch feeds that exist in database
    feeds = Feed.objects.filter(feed_address__in=urls)[:limit]

    # Build response with feed details and stories
    channels = {}
    for feed in feeds:
        channels[feed.pk] = {
            "feed": feed.canonical(include_favicon=False, full=True),
            "stories": feed.get_stories(limit=5),
        }

    logging.user(request, "~FCPopular channels (%s): ~SB%s feeds" % (channel_type, len(channels)))
    return {"channels": channels, "type": channel_type}


@json.json_view
def popular_feeds(request):
    """
    Returns curated popular feeds from the PopularFeed model.
    Supports filtering by type and category, with pagination.
    Used by Add Site modal tabs (YouTube, Reddit, Newsletters, Podcasts)
    and the Search tab empty state (type=all for a mix of all types).
    """
    feed_type = request.GET.get("type", "").strip()
    category = request.GET.get("category", "").strip()
    subcategory = request.GET.get("subcategory", "").strip()
    platform = request.GET.get("platform", "").strip()
    limit = min(int(request.GET.get("limit", 50)), 200)
    offset = int(request.GET.get("offset", 0))
    include_stories = request.GET.get("include_stories", "false").lower() == "true"

    if not feed_type:
        return {"code": -1, "message": "Feed type is required", "feeds": []}

    # Query PopularFeed records — type=all returns a mix of all feed types
    base_filter = dict(is_active=True)
    if feed_type != "all":
        base_filter["feed_type"] = feed_type
    qs = PopularFeed.objects.filter(**base_filter)

    if category and category != "all":
        # Try exact match first, then fall back to normalized match
        # (strips non-alphanumeric chars for URL slug compatibility, e.g. "food cooking" matches "food & cooking")
        exact = qs.filter(category=category)
        if exact.exists():
            qs = exact
        else:
            normalized = re.sub(r"\s+", " ", re.sub(r"[^a-zA-Z0-9\s]", "", category)).strip().lower()
            matching_cats = [
                cat_name
                for cat_name in qs.values_list("category", flat=True).distinct()
                if re.sub(r"\s+", " ", re.sub(r"[^a-zA-Z0-9\s]", "", cat_name)).strip().lower() == normalized
            ]
            if matching_cats:
                qs = qs.filter(category=matching_cats[0])
            else:
                qs = qs.filter(category=category)

    if subcategory and subcategory != "all":
        exact_sub = qs.filter(subcategory=subcategory)
        if exact_sub.exists():
            qs = exact_sub
        else:
            normalized_sub = re.sub(r"\s+", " ", re.sub(r"[^a-zA-Z0-9\s]", "", subcategory)).strip().lower()
            matching_subs = [
                sub_name
                for sub_name in qs.values_list("subcategory", flat=True).distinct()
                if re.sub(r"\s+", " ", re.sub(r"[^a-zA-Z0-9\s]", "", sub_name)).strip().lower() == normalized_sub
            ]
            if matching_subs:
                qs = qs.filter(subcategory=matching_subs[0])
            else:
                qs = qs.filter(subcategory=subcategory)

    if platform and platform != "all":
        qs = qs.filter(platform=platform)

    query = request.GET.get("query", "").strip()
    extra_semantic_feeds = []  # Feed objects found via embeddings but not in PopularFeed table
    if query:
        # Text search across title, description, and feed_url
        qs = qs.filter(Q(title__icontains=query) | Q(description__icontains=query) | Q(feed_url__icontains=query))

        # Semantic search via embeddings to find related feeds
        if len(query) >= 3:
            try:
                text_pf_ids = set(qs.values_list("id", flat=True))
                semantic_results = SearchFeed.hybrid_query(query, max_results=50)
                semantic_feed_ids = [int(r["feed_id"]) for r in semantic_results]

                if semantic_feed_ids:
                    # Find PopularFeed entries linked to semantically matching feeds,
                    # respecting the same category/subcategory filters as the text search
                    linked_qs = PopularFeed.objects.filter(is_active=True, feed_id__in=semantic_feed_ids)
                    if feed_type != "all":
                        linked_qs = linked_qs.filter(feed_type=feed_type)
                    if category and category != "all":
                        linked_qs = linked_qs.filter(category=category)
                    if subcategory and subcategory != "all":
                        linked_qs = linked_qs.filter(subcategory=subcategory)
                    semantic_pf_ids = set(linked_qs.values_list("id", flat=True)) - text_pf_ids

                    if semantic_pf_ids:
                        qs = PopularFeed.objects.filter(id__in=text_pf_ids | semantic_pf_ids)

                    # Find Feed objects matching URL pattern that aren't in PopularFeed
                    # (skip when filtering by category/subcategory since these feeds lack category metadata)
                    url_patterns = {"reddit": "reddit.com", "youtube": "youtube.com"}
                    if feed_type in url_patterns and (not category or category == "all"):
                        linked_feed_ids = set(
                            PopularFeed.objects.filter(
                                is_active=True, feed_id__in=semantic_feed_ids
                            ).values_list("feed_id", flat=True)
                        )
                        unlinked_ids = [fid for fid in semantic_feed_ids if fid not in linked_feed_ids]
                        if unlinked_ids:
                            extra_semantic_feeds = list(
                                Feed.objects.filter(
                                    pk__in=unlinked_ids,
                                    feed_address__icontains=url_patterns[feed_type],
                                )
                            )
            except Exception as e:
                logging.debug(f" ***> ~FRSemantic search failed for popular_feeds: {e}")

    # Build grouped category structure with feed counts:
    # [{name, feed_count, subcategories: [{name, feed_count}, ...]}, ...]
    cat_qs = PopularFeed.objects.filter(**base_filter)
    if platform and platform != "all":
        cat_qs = cat_qs.filter(platform=platform)

    # Clear default ordering to avoid GROUP BY interference, then count feeds
    unordered_qs = cat_qs.order_by()
    cat_feed_counts = dict(
        unordered_qs.values("category").annotate(count=Count("id")).values_list("category", "count")
    )
    subcat_feed_counts = {}
    for row in unordered_qs.values("category", "subcategory").annotate(count=Count("id")):
        subcat_feed_counts[(row["category"], row["subcategory"])] = row["count"]

    cat_subcats = list(
        cat_qs.values("category", "subcategory").distinct().order_by("category", "subcategory")
    )
    # Group subcategories under parent categories
    grouped_categories = []
    current_cat = None
    current_entry = None
    for row in cat_subcats:
        cat_name = row["category"]
        subcat_name = row["subcategory"]
        if cat_name != current_cat:
            if current_entry:
                grouped_categories.append(current_entry)
            current_cat = cat_name
            current_entry = {
                "name": cat_name,
                "feed_count": cat_feed_counts.get(cat_name, 0),
                "subcategories": [],
            }
        if subcat_name:
            current_entry["subcategories"].append(
                {
                    "name": subcat_name,
                    "feed_count": subcat_feed_counts.get((cat_name, subcat_name), 0),
                }
            )
    if current_entry:
        grouped_categories.append(current_entry)

    # Flat categories list for backwards compatibility
    categories = list(
        cat_qs.values_list("category", flat=True)
        .distinct()
        .order_by("category")
    )

    # Platform counts (unfiltered by platform so pills always show totals)
    platform_base_qs = PopularFeed.objects.filter(**base_filter).order_by()
    platform_counts = dict(
        platform_base_qs.values("platform").annotate(count=Count("id")).values_list("platform", "count")
    )

    # For type=all, sort by subscriber_count desc to surface the best feeds first
    if feed_type == "all":
        qs = qs.order_by("-subscriber_count")

    total = qs.count() + len(extra_semantic_feeds)
    popular_feeds_list = list(qs[offset : offset + limit + 1])

    # Append semantic Feed objects if PopularFeed results don't fill the page
    remaining_slots = limit + 1 - len(popular_feeds_list)
    semantic_feeds_page = []
    if remaining_slots > 0 and extra_semantic_feeds:
        semantic_offset = max(0, offset - qs.count())
        semantic_feeds_page = extra_semantic_feeds[semantic_offset : semantic_offset + remaining_slots]
        popular_feeds_list.extend(semantic_feeds_page)

    has_more = len(popular_feeds_list) > limit
    popular_feeds_list = popular_feeds_list[:limit]

    # Batch-load linked Feed objects and their icons
    feed_ids = [pf.feed_id for pf in popular_feeds_list if isinstance(pf, PopularFeed) and pf.feed_id]
    feed_ids.extend([f.pk for f in semantic_feeds_page if isinstance(f, Feed)])
    feeds_by_id = {}
    feed_icons = {}
    if feed_ids:
        feeds_by_id = {f.pk: f for f in Feed.objects.filter(pk__in=feed_ids)}
        feed_icons = {icon.feed_id: icon for icon in MFeedIcon.objects.filter(feed_id__in=feed_ids)}

    results = []
    for pf in popular_feeds_list:
        if isinstance(pf, Feed):
            # Semantic match from Feed table, not in PopularFeed
            feed_obj = pf
            entry = {
                "id": None,
                "feed_id": feed_obj.pk,
                "feed_type": feed_type,
                "category": "",
                "subcategory": "",
                "title": feed_obj.feed_title,
                "description": feed_obj.data.feed_tagline if feed_obj.data else "",
                "feed_url": feed_obj.feed_address,
                "thumbnail_url": "",
                "platform": "",
                "subscriber_count": feed_obj.num_subscribers,
                "feed": feed_obj.canonical(include_favicon=False, full=True),
            }
            if feed_obj.pk in feed_icons:
                icon = feed_icons[feed_obj.pk]
                if icon.data:
                    entry["feed"]["favicon_color"] = icon.color
                    entry["feed"]["favicon"] = icon.data
            if include_stories:
                entry["stories"] = feed_obj.get_stories(limit=5)
            results.append(entry)
            continue

        entry = {
            "id": pf.pk,
            "feed_id": pf.feed_id,
            "feed_type": pf.feed_type,
            "category": pf.category,
            "subcategory": pf.subcategory,
            "title": pf.title,
            "description": pf.description,
            "feed_url": pf.feed_url,
            "thumbnail_url": pf.thumbnail_url,
            "platform": pf.platform,
            "subscriber_count": pf.subscriber_count,
        }

        # Include linked Feed canonical data if available
        if pf.feed_id and pf.feed_id in feeds_by_id:
            feed_obj = feeds_by_id[pf.feed_id]
            entry["feed"] = feed_obj.canonical(include_favicon=False, full=True)

            # Override with PopularFeed data when Feed hasn't been fetched yet
            if feed_obj.feed_title in ("", "[Untitled]") and pf.title:
                entry["feed"]["feed_title"] = pf.title
            if feed_obj.num_subscribers < 0 and pf.subscriber_count > 0:
                entry["feed"]["num_subscribers"] = pf.subscriber_count

            # Include favicon
            if pf.feed_id in feed_icons:
                icon = feed_icons[pf.feed_id]
                if icon.data:
                    entry["feed"]["favicon_color"] = icon.color
                    entry["feed"]["favicon"] = icon.data

            # Include stories if requested (for list view mode)
            if include_stories:
                entry["stories"] = feed_obj.get_stories(limit=5)
        else:
            entry["feed"] = None
            if include_stories:
                entry["stories"] = []

        results.append(entry)

    logging.user(
        request,
        "~FCPopular feeds (%s/%s/%s): ~SB%s feeds (offset=%s)"
        % (feed_type, category or "all", subcategory or "all", len(results), offset),
    )
    return {
        "feeds": results,
        "categories": categories,
        "grouped_categories": grouped_categories,
        "platform_counts": platform_counts,
        "total": total,
        "has_more": has_more,
    }


@json.json_view
def link_popular_feed(request):
    """
    Creates a Feed record for a PopularFeed that hasn't been linked yet.
    Uses direct Feed.objects.create instead of get_feed_from_url to avoid
    slow HTTP feed discovery. Returns the feed_id for use by Try/Stats buttons.
    """
    popular_feed_id = request.GET.get("id") or request.POST.get("id")
    if not popular_feed_id:
        return {"code": -1, "message": "Missing popular feed id"}

    try:
        pf = PopularFeed.objects.get(pk=popular_feed_id, is_active=True)
    except PopularFeed.DoesNotExist:
        return {"code": -1, "message": "Popular feed not found"}

    if pf.feed_id:
        return {"code": 1, "feed_id": pf.feed_id}

    # Check if a Feed with this address already exists
    existing = Feed.objects.filter(feed_address=pf.feed_url, branch_from_feed__isnull=True).first()
    if existing:
        pf.feed_id = existing.pk
        pf.save(update_fields=["feed"])
        return {"code": 1, "feed_id": existing.pk}

    # Create a bare Feed record directly — no feed discovery, no HTTP requests
    feed = Feed.objects.create(feed_address=pf.feed_url, feed_title=pf.title or "")
    pf.feed_id = feed.pk
    pf.save(update_fields=["feed"])

    logging.user(request, "~FCLinked popular feed ~SB%s~SN to feed ~SB%s" % (pf.title, feed.pk))
    return {"code": 1, "feed_id": feed.pk}
