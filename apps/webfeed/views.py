import re
import uuid

from django.views.decorators.http import require_http_methods

from apps.rss_feeds.models import Feed
from utils import json_functions as json
from utils import log as logging
from utils.user_functions import ajax_login_required
from utils.view_functions import required_params

from .models import MWebFeedConfig
from .tasks import AnalyzeWebFeedPage

REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9_\-]{8,64}$")
URL_RE = re.compile(r"^https?://[^\s]+$")


@ajax_login_required
@require_http_methods(["POST"])
@required_params("url")
@json.json_view
def analyze(request):
    """Kick off a Celery task to analyze a web page for story patterns."""
    url = request.POST.get("url", "").strip()
    request_id = request.POST.get("request_id")

    if not URL_RE.match(url):
        return {"code": -1, "message": "Please enter a valid URL starting with http:// or https://"}

    if request_id:
        if not REQUEST_ID_RE.match(request_id):
            return {"code": -1, "message": "Invalid request identifier"}
    else:
        request_id = str(uuid.uuid4())

    logging.user(request.user, f"~BB~FWWeb Feed: Analyzing ~SB{url}~SN")

    AnalyzeWebFeedPage.apply_async(
        kwargs={
            "user_id": request.user.pk,
            "url": url,
            "request_id": request_id,
        },
        queue="archive_queue",  # TODO: change back to "work_queue" before launch
    )

    return {
        "code": 1,
        "message": "Analyzing page",
        "request_id": request_id,
    }


@ajax_login_required
@require_http_methods(["POST"])
@required_params("url", "variant_index")
@json.json_view
def subscribe(request):
    """Create a web feed subscription from a selected variant."""
    url = request.POST.get("url", "").strip()
    variant_index = int(request.POST.get("variant_index", 0))
    folder = request.POST.get("folder", "")
    staleness_days = int(request.POST.get("staleness_days", 30))
    mark_unread_on_change = request.POST.get("mark_unread_on_change", "false") == "true"

    # Variant XPath data from the analysis
    story_container_xpath = request.POST.get("story_container_xpath", "")
    title_xpath = request.POST.get("title_xpath", "")
    link_xpath = request.POST.get("link_xpath", "")
    content_xpath = request.POST.get("content_xpath", "")
    image_xpath = request.POST.get("image_xpath", "")
    author_xpath = request.POST.get("author_xpath", "")
    date_xpath = request.POST.get("date_xpath", "")
    html_hash = request.POST.get("html_hash", "")
    feed_title = request.POST.get("feed_title", "").strip()

    if not URL_RE.match(url):
        return {"code": -1, "message": "Invalid URL"}

    if not story_container_xpath or not title_xpath or not link_xpath:
        return {"code": -1, "message": "Missing XPath expressions for story extraction"}

    feed_address = f"webfeed:{url}"

    # Check if feed already exists
    try:
        feed = Feed.objects.get(feed_address=feed_address)
    except Feed.DoesNotExist:
        feed = Feed.objects.create(
            feed_address=feed_address,
            feed_link=url,
            feed_title=feed_title or url.split("//")[-1].split("/")[0],
            fetched_once=False,
            known_good=True,
        )
    except Feed.MultipleObjectsReturned:
        feed = Feed.objects.filter(feed_address=feed_address).first()

    # Create or update MWebFeedConfig
    try:
        config = MWebFeedConfig.objects.get(feed_id=feed.pk)
    except MWebFeedConfig.DoesNotExist:
        config = MWebFeedConfig(feed_id=feed.pk)

    config.url = url
    config.story_container_xpath = story_container_xpath
    config.title_xpath = title_xpath
    config.link_xpath = link_xpath
    config.content_xpath = content_xpath or ""
    config.image_xpath = image_xpath or ""
    config.author_xpath = author_xpath or ""
    config.date_xpath = date_xpath or ""
    config.staleness_days = staleness_days
    config.mark_unread_on_change = mark_unread_on_change
    config.variant_index = variant_index
    config.analysis_html_hash = html_hash
    config.consecutive_failures = 0
    config.needs_reanalysis = False
    config.save()

    # Create user subscription
    from apps.reader.models import UserSubscription

    try:
        us = UserSubscription.objects.get(user=request.user, feed=feed)
    except UserSubscription.DoesNotExist:
        us = UserSubscription.objects.create(
            user=request.user,
            feed=feed,
            active=True,
            user_title=feed.feed_title,
        )
        from apps.reader.models import UserSubscriptionFolders
        from utils.feed_functions import add_object_to_folder
        from utils import json_functions as json_util

        usf, created = UserSubscriptionFolders.objects.get_or_create(
            user=request.user, defaults={"folders": "[]"}
        )
        user_sub_folders = json_util.decode(usf.folders) if usf.folders else []
        user_sub_folders = add_object_to_folder(feed.pk, folder, user_sub_folders)
        usf.folders = json_util.encode(user_sub_folders)
        usf.save()

    logging.user(request.user, f"~BB~FWWeb Feed: Subscribed to ~SB{url}~SN (feed {feed.pk})")

    # Update cached subscriber counts so update_webfeed() sees the new subscription
    feed.count_subscribers()

    # Trigger initial fetch if user has archive subscription
    from apps.profile.models import Profile

    profile = Profile.objects.get(user=request.user)
    if profile.is_archive:
        feed.update()

    return {
        "code": 1,
        "feed": feed.canonical(),
        "message": "Subscribed to web feed",
    }


@ajax_login_required
@require_http_methods(["POST"])
@required_params("feed_id")
@json.json_view
def reanalyze(request):
    """Re-run LLM analysis for a broken web feed."""
    feed_id = int(request.POST.get("feed_id"))
    request_id = request.POST.get("request_id")

    if request_id:
        if not REQUEST_ID_RE.match(request_id):
            return {"code": -1, "message": "Invalid request identifier"}
    else:
        request_id = str(uuid.uuid4())

    try:
        feed = Feed.objects.get(pk=feed_id)
    except Feed.DoesNotExist:
        return {"code": -1, "message": "Feed not found"}

    if not feed.feed_address.startswith("webfeed:"):
        return {"code": -1, "message": "Not a web feed"}

    url = feed.feed_address[len("webfeed:"):]

    logging.user(request.user, f"~BB~FWWeb Feed: Re-analyzing ~SB{url}~SN (feed {feed_id})")

    AnalyzeWebFeedPage.apply_async(
        kwargs={
            "user_id": request.user.pk,
            "url": url,
            "request_id": request_id,
        },
        queue="archive_queue",  # TODO: change back to "work_queue" before launch
    )

    return {
        "code": 1,
        "message": "Re-analyzing page",
        "request_id": request_id,
        "feed_id": feed_id,
    }
