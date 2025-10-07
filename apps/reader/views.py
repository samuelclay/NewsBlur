import base64
import concurrent
import datetime
import http.client
import random
import re
import socket
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request
import zlib

import redis
import requests
from django.conf import settings
from django.contrib.auth import login as login_user
from django.contrib.auth import logout as logout_user
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
from django.core.mail import EmailMultiAlternatives
from django.core.validators import validate_email
from django.db import IntegrityError
from django.db.models import Q
from django.db.utils import DatabaseError
from django.http import (
    Http404,
    HttpResponse,
    HttpResponseForbidden,
    HttpResponseRedirect,
    UnreadablePostError,
)
from django.shortcuts import get_object_or_404, render
from django.template.loader import render_to_string
from django.urls import reverse
from django.utils import feedgenerator
from django.utils.encoding import smart_str
from django.views.decorators.cache import never_cache
from mongoengine.queryset import NotUniqueError, OperationError

from apps.analyzer.models import (
    MClassifierAuthor,
    MClassifierFeed,
    MClassifierTag,
    MClassifierTitle,
    apply_classifier_authors,
    apply_classifier_feeds,
    apply_classifier_tags,
    apply_classifier_titles,
    get_classifiers_for_user,
    sort_classifiers_by_feed,
)
from apps.notifications.models import MUserFeedNotification
from apps.profile.models import MCustomStyling, MDashboardRiver, Profile
from apps.reader.forms import FeatureForm, LoginForm, SignupForm
from apps.reader.models import (
    Feature,
    RUserStory,
    RUserUnreadStory,
    UserSubscription,
    UserSubscriptionFolders,
)
from apps.recommendations.models import RecommendedFeed
from apps.rss_feeds.models import MFeedIcon, MSavedSearch, MStarredStoryCounts
from apps.search.models import MUserSearch
from apps.statistics.models import MAnalyticsLoader, MStatistics
from apps.statistics.rstats import RStats

# from apps.search.models import SearchStarredStory
try:
    from apps.rss_feeds.models import (
        DuplicateFeed,
        Feed,
        MFeedPage,
        MStarredStory,
        MStory,
    )
except:
    pass
import tweepy

from apps.categories.models import MCategory
from apps.rss_feeds.tasks import ScheduleImmediateFetches
from apps.social.models import (
    MActivity,
    MInteraction,
    MSharedStory,
    MSocialProfile,
    MSocialServices,
    MSocialSubscription,
)
from apps.social.views import load_social_page
from utils import json_functions as json
from utils import log as logging
from utils.feed_functions import relative_timesince
from utils.ratelimit import ratelimit
from utils.story_functions import (
    format_story_link_date__long,
    format_story_link_date__short,
    strip_tags,
)
from utils.user_functions import ajax_login_required, extract_user_agent, get_user
from utils.view_functions import (
    get_argument_or_404,
    is_true,
    render_to,
    required_params,
)
from vendor.timezones.utilities import localtime_for_timezone

BANNED_URLS = [
    "brentozar.com",
]
ALLOWED_SUBDOMAINS = [
    "dev",
    "www",
    "hwww",
    "dwww",
    # 'beta',  # Comment to redirect beta -> www, uncomment to allow beta -> staging (+ dns changes)
    "staging",
    "hstaging",
    "discovery",
    "debug",
    "debug3",
    "staging2",
    "staging3",
    "nb",
]


def get_subdomain(request):
    host = request.META.get("HTTP_HOST")
    if host and host.count(".") >= 2:
        return host.split(".")[0]
    else:
        return None


@never_cache
@render_to("reader/dashboard.xhtml")
def index(request, **kwargs):
    subdomain = get_subdomain(request)
    if request.method == "GET" and subdomain and subdomain not in ALLOWED_SUBDOMAINS:
        username = request.subdomain or subdomain
        if "." in username:
            username = username.split(".")[0]
        user = User.objects.filter(username=username)
        if not user:
            user = User.objects.filter(username__iexact=username)
        if user:
            user = user[0]
        if not user:
            return HttpResponseRedirect("http://%s%s" % (Site.objects.get_current().domain, reverse("index")))
        return load_social_page(request, user_id=user.pk, username=request.subdomain, **kwargs)
    if request.user.is_anonymous:
        return welcome(request, **kwargs)
    else:
        return dashboard(request, **kwargs)


def dashboard(request, **kwargs):
    user = request.user
    feed_count = UserSubscription.objects.filter(user=request.user).count()
    # recommended_feeds = RecommendedFeed.objects.filter(is_public=True,
    #                                                    approved_date__lte=datetime.datetime.now()
    #                                                    ).select_related('feed')[:2]
    unmoderated_feeds = []
    if user.is_staff:
        unmoderated_feeds = RecommendedFeed.objects.filter(
            is_public=False, declined_date__isnull=True
        ).select_related("feed")[:2]
    statistics = MStatistics.all()
    social_profile = MSocialProfile.get_user(user.pk)
    custom_styling = MCustomStyling.get_user(user.pk)
    dashboard_rivers = MDashboardRiver.get_user_rivers(user.pk)
    preferences = json.decode(user.profile.preferences)

    if not user.is_active:
        url = "https://%s%s" % (Site.objects.get_current().domain, reverse("stripe-form"))
        return HttpResponseRedirect(url)

    logging.user(request, "~FBLoading dashboard")

    return {
        "user_profile": user.profile,
        "preferences": preferences,
        "feed_count": feed_count,
        "custom_styling": custom_styling,
        "dashboard_rivers": dashboard_rivers,
        "account_images": list(range(1, 4)),
        # 'recommended_feeds' : recommended_feeds,
        "unmoderated_feeds": unmoderated_feeds,
        "statistics": statistics,
        "social_profile": social_profile,
        "debug": settings.DEBUG,
        "debug_assets": settings.DEBUG_ASSETS,
    }, "reader/dashboard.xhtml"


@render_to("reader/dashboard.xhtml")
def welcome_req(request, **kwargs):
    return welcome(request, **kwargs)


def welcome(request, **kwargs):
    user = get_user(request)
    statistics = MStatistics.all()
    social_profile = MSocialProfile.get_user(user.pk)

    if request.method == "POST":
        if request.POST.get("submit", "").startswith("log"):
            login_form = LoginForm(request.POST, prefix="login")
            signup_form = SignupForm(prefix="signup")
        else:
            signup_form = SignupForm(request.POST, prefix="signup")
            return {"form": signup_form}, "accounts/signup.html"
    else:
        login_form = LoginForm(prefix="login")
        signup_form = SignupForm(prefix="signup")

    logging.user(request, "~FBLoading welcome")

    return {
        "user_profile": hasattr(user, "profile") and user.profile,
        "login_form": login_form,
        "signup_form": signup_form,
        "statistics": statistics,
        "social_profile": social_profile,
        "post_request": request.method == "POST",
    }, "reader/welcome.xhtml"


@never_cache
def login(request):
    code = -1
    message = ""
    if request.method == "POST":
        form = LoginForm(request.POST, prefix="login")
        if form.is_valid():
            login_user(request, form.get_user(), backend="django.contrib.auth.backends.ModelBackend")
            if request.POST.get("api"):
                logging.user(form.get_user(), "~FG~BB~SKiPhone Login~FW")
                code = 1
            else:
                logging.user(form.get_user(), "~FG~BBLogin~FW")
                next_url = request.POST.get("next", "")
                if next_url:
                    return HttpResponseRedirect(next_url)
                return HttpResponseRedirect(reverse("index"))
        else:
            message = list(form.errors.items())[0][1][0]

    if request.POST.get("api"):
        return HttpResponse(json.encode(dict(code=code, message=message)), content_type="application/json")
    else:
        return index(request)


@never_cache
@render_to("accounts/signup.html")
def signup(request):
    if request.method == "POST":
        if settings.ENFORCE_SIGNUP_CAPTCHA:
            signup_form = SignupForm(request.POST, prefix="signup")
            return {"form": signup_form}

        form = SignupForm(prefix="signup", data=request.POST)
        if form.is_valid():
            new_user = form.save()
            login_user(request, new_user, backend="django.contrib.auth.backends.ModelBackend")
            logging.user(new_user, "~FG~SB~BBNEW SIGNUP: ~FW%s" % new_user.email)
            if not new_user.is_active:
                url = "https://%s%s" % (Site.objects.get_current().domain, reverse("stripe-form"))
                return HttpResponseRedirect(url)
            else:
                return HttpResponseRedirect(reverse("index"))

    return index(request)


@never_cache
def logout(request):
    logging.user(request, "~FG~BBLogout~FW")
    logout_user(request)

    if request.GET.get("api"):
        return HttpResponse(json.encode(dict(code=1)), content_type="application/json")
    else:
        return HttpResponseRedirect(reverse("index"))


def autologin(request, username, secret):
    next = request.GET.get("next", "")

    if not username or not secret:
        return HttpResponseForbidden()

    profile = Profile.objects.filter(user__username=username, secret_token=secret)
    if not profile:
        return HttpResponseForbidden()

    user = profile[0].user
    user.backend = settings.AUTHENTICATION_BACKENDS[0]
    login_user(request, user, backend="django.contrib.auth.backends.ModelBackend")
    logging.user(user, "~FG~BB~SKAuto-Login. Next stop: %s~FW" % (next if next else "Homepage",))

    if next and not next.startswith("/"):
        next = "?next=" + next
        return HttpResponseRedirect(reverse("index") + next)
    elif next:
        return HttpResponseRedirect(next)
    else:
        return HttpResponseRedirect(reverse("index"))


@ratelimit(minutes=1, requests=60)
@never_cache
@json.json_view
def load_feeds(request):
    user = get_user(request)
    feeds = {}
    include_favicons = is_true(request.GET.get("include_favicons", False))
    flat = is_true(request.GET.get("flat", False))
    update_counts = is_true(request.GET.get("update_counts", True))
    version = int(request.GET.get("v", 1))

    if include_favicons == "false":
        include_favicons = False
    if update_counts == "false":
        update_counts = False
    if flat == "false":
        flat = False

    if flat:
        return load_feeds_flat(request)

    platform = extract_user_agent(request)
    if platform in ["iPhone", "iPad", "Androd"]:
        # Remove this check once the iOS and Android updates go out which have update_counts=False
        # and then guarantee a refresh_feeds call
        update_counts = False

    try:
        folders = UserSubscriptionFolders.objects.get(user=user)
    except UserSubscriptionFolders.DoesNotExist:
        data = dict(feeds=[], folders=[])
        return data
    except UserSubscriptionFolders.MultipleObjectsReturned:
        UserSubscriptionFolders.objects.filter(user=user)[1:].delete()
        folders = UserSubscriptionFolders.objects.get(user=user)

    user_subs = UserSubscription.objects.select_related("feed").filter(user=user)
    notifications = MUserFeedNotification.feeds_for_user(user.pk)

    day_ago = datetime.datetime.now() - datetime.timedelta(days=1)
    scheduled_feeds = []
    for sub in user_subs:
        pk = sub.feed_id
        if update_counts and sub.needs_unread_recalc:
            sub.calculate_feed_scores(silent=True)
        feeds[pk] = sub.canonical(include_favicon=include_favicons)

        if not sub.active:
            continue
        if pk in notifications:
            feeds[pk].update(notifications[pk])
        if not sub.feed.active and not sub.feed.has_feed_exception:
            scheduled_feeds.append(sub.feed.pk)
        elif sub.feed.active_subscribers <= 0:
            scheduled_feeds.append(sub.feed.pk)
        elif sub.feed.next_scheduled_update < day_ago:
            scheduled_feeds.append(sub.feed.pk)

    if len(scheduled_feeds) > 0 and request.user.is_authenticated:
        logging.user(
            request,
            "~SN~FMTasking the scheduling immediate fetch of ~SB%s~SN feeds..." % len(scheduled_feeds),
        )
        ScheduleImmediateFetches.apply_async(kwargs=dict(feed_ids=scheduled_feeds, user_id=user.pk))

    starred_counts, starred_count = MStarredStoryCounts.user_counts(user.pk, include_total=True)
    if not starred_count and len(starred_counts):
        starred_count = MStarredStory.objects(user_id=user.pk).count()

    saved_searches = MSavedSearch.user_searches(user.pk)

    social_params = {
        "user_id": user.pk,
        "include_favicon": include_favicons,
        "update_counts": update_counts,
    }
    social_feeds = MSocialSubscription.feeds(**social_params)
    social_profile = MSocialProfile.profile(user.pk)
    social_services = MSocialServices.profile(user.pk)
    dashboard_rivers = MDashboardRiver.get_user_rivers(user.pk)

    categories = None
    if not user_subs:
        categories = MCategory.serialize()

    logging.user(
        request,
        "~FB~SBLoading ~FY%s~FB/~FM%s~FB feeds/socials%s"
        % (len(list(feeds.keys())), len(social_feeds), ". ~FCUpdating counts." if update_counts else ""),
    )

    data = {
        "feeds": list(feeds.values()) if version == 2 else feeds,
        "social_feeds": social_feeds,
        "social_profile": social_profile,
        "social_services": social_services,
        "user_profile": user.profile,
        "is_staff": user.is_staff,
        "user_id": user.pk,
        "folders": json.decode(folders.folders),
        "starred_count": starred_count,
        "starred_counts": starred_counts,
        "saved_searches": saved_searches,
        "dashboard_rivers": dashboard_rivers,
        "categories": categories,
        "share_ext_token": user.profile.secret_token,
    }
    return data


@json.json_view
def load_feed_favicons(request):
    user = get_user(request)
    feed_ids = request.GET.getlist("feed_ids") or request.GET.getlist("feed_ids[]")

    if not feed_ids:
        user_subs = UserSubscription.objects.select_related("feed").filter(user=user, active=True)
        feed_ids = [sub["feed__pk"] for sub in user_subs.values("feed__pk")]

    feed_icons = dict([(i.feed_id, i.data) for i in MFeedIcon.objects(feed_id__in=feed_ids)])

    return feed_icons


def load_feeds_flat(request):
    user = request.user
    include_favicons = is_true(request.GET.get("include_favicons", False))
    update_counts = is_true(request.GET.get("update_counts", True))
    include_inactive = is_true(request.GET.get("include_inactive", False))
    background_ios = is_true(request.GET.get("background_ios", False))

    feeds = {}
    inactive_feeds = {}
    day_ago = datetime.datetime.now() - datetime.timedelta(days=1)
    scheduled_feeds = []
    iphone_version = "2.1"  # Preserved forever. Don't change.
    latest_ios_build = "52"
    latest_ios_version = "5.0.0b2"

    if include_favicons == "false":
        include_favicons = False
    if update_counts == "false":
        update_counts = False

    if not user.is_authenticated:
        return HttpResponseForbidden()

    try:
        folders = UserSubscriptionFolders.objects.get(user=user)
    except UserSubscriptionFolders.DoesNotExist:
        folders = []

    user_subs = UserSubscription.objects.select_related("feed").filter(user=user, active=True)
    notifications = MUserFeedNotification.feeds_for_user(user.pk)
    if not user_subs and folders:
        folders.auto_activate()
        user_subs = UserSubscription.objects.select_related("feed").filter(user=user, active=True)
    if include_inactive:
        inactive_subs = UserSubscription.objects.select_related("feed").filter(user=user, active=False)

    for sub in user_subs:
        pk = sub.feed_id
        if update_counts and sub.needs_unread_recalc:
            sub.calculate_feed_scores(silent=True)
        feeds[pk] = sub.canonical(include_favicon=include_favicons)
        if not sub.feed.active and not sub.feed.has_feed_exception:
            scheduled_feeds.append(sub.feed.pk)
        elif sub.feed.active_subscribers <= 0:
            scheduled_feeds.append(sub.feed.pk)
        elif sub.feed.next_scheduled_update < day_ago:
            scheduled_feeds.append(sub.feed.pk)
        if pk in notifications:
            feeds[pk].update(notifications[pk])

    if include_inactive:
        for sub in inactive_subs:
            inactive_feeds[sub.feed_id] = sub.canonical(include_favicon=include_favicons)

    if len(scheduled_feeds) > 0 and request.user.is_authenticated:
        logging.user(
            request,
            "~SN~FMTasking the scheduling immediate fetch of ~SB%s~SN feeds..." % len(scheduled_feeds),
        )
        ScheduleImmediateFetches.apply_async(kwargs=dict(feed_ids=scheduled_feeds, user_id=user.pk))

    flat_folders = []
    flat_folders_with_inactive = []
    if folders:
        flat_folders = folders.flatten_folders(feeds=feeds)
        flat_folders_with_inactive = folders.flatten_folders(feeds=feeds, inactive_feeds=inactive_feeds)

    social_params = {
        "user_id": user.pk,
        "include_favicon": include_favicons,
        "update_counts": update_counts,
    }
    social_feeds = MSocialSubscription.feeds(**social_params)
    social_profile = MSocialProfile.profile(user.pk)
    social_services = MSocialServices.profile(user.pk)
    starred_counts, starred_count = MStarredStoryCounts.user_counts(user.pk, include_total=True)
    if not starred_count and len(starred_counts):
        starred_count = MStarredStory.objects(user_id=user.pk).count()

    categories = None
    if not user_subs:
        categories = MCategory.serialize()

    saved_searches = MSavedSearch.user_searches(user.pk)
    dashboard_rivers = MDashboardRiver.get_user_rivers(user.pk)

    logging.user(
        request,
        "~FB~SBLoading ~FY%s~FB/~FM%s~FB/~FR%s~FB feeds/socials/inactive ~FMflat~FB%s%s"
        % (
            len(list(feeds.keys())),
            len(social_feeds),
            len(inactive_feeds),
            ". ~FCUpdating counts." if update_counts else "",
            " ~BB(background fetch)" if background_ios else "",
        ),
    )

    data = {
        "flat_folders": flat_folders,
        "flat_folders_with_inactive": flat_folders_with_inactive,
        "feeds": feeds,
        "inactive_feeds": inactive_feeds if include_inactive else {"0": "Include `include_inactive=true`"},
        "social_feeds": social_feeds,
        "social_profile": social_profile,
        "social_services": social_services,
        "user": user.username,
        "user_id": user.pk,
        "is_staff": user.is_staff,
        "user_profile": user.profile,
        "iphone_version": iphone_version,
        "latest_ios_build": latest_ios_build,
        "latest_ios_version": latest_ios_version,
        "categories": categories,
        "starred_count": starred_count,
        "starred_counts": starred_counts,
        "saved_searches": saved_searches,
        "dashboard_rivers": dashboard_rivers,
        "share_ext_token": user.profile.secret_token,
    }
    return data


class ratelimit_refresh_feeds(ratelimit):
    def should_ratelimit(self, request):
        feed_ids = request.POST.getlist("feed_id") or request.POST.getlist("feed_id[]")
        if len(feed_ids) == 1:
            return False
        return True


@ratelimit_refresh_feeds(minutes=1, requests=30)
@never_cache
@json.json_view
def refresh_feeds(request):
    get_post = getattr(request, request.method)
    start = datetime.datetime.now()
    start_time = time.time()
    user = get_user(request)
    feed_ids = get_post.getlist("feed_id") or get_post.getlist("feed_id[]")
    check_fetch_status = get_post.get("check_fetch_status")
    favicons_fetching = get_post.getlist("favicons_fetching") or get_post.getlist("favicons_fetching[]")
    social_feed_ids = [feed_id for feed_id in feed_ids if "social:" in feed_id]
    feed_ids = list(set(feed_ids) - set(social_feed_ids))

    feeds = {}
    if feed_ids or (not social_feed_ids and not feed_ids):
        feeds = UserSubscription.feeds_with_updated_counts(
            user, feed_ids=feed_ids, check_fetch_status=check_fetch_status
        )
    checkpoint1 = datetime.datetime.now()
    social_feeds = {}
    if social_feed_ids or (not social_feed_ids and not feed_ids):
        social_feeds = MSocialSubscription.feeds_with_updated_counts(user, social_feed_ids=social_feed_ids)
    checkpoint2 = datetime.datetime.now()

    favicons_fetching = [int(f) for f in favicons_fetching if f]
    feed_icons = {}
    if favicons_fetching:
        feed_icons = dict([(i.feed_id, i) for i in MFeedIcon.objects(feed_id__in=favicons_fetching)])
        for feed_id, feed in list(feeds.items()):
            if feed_id in favicons_fetching and feed_id in feed_icons:
                feeds[feed_id]["favicon"] = feed_icons[feed_id].data
                feeds[feed_id]["favicon_color"] = feed_icons[feed_id].color
                feeds[feed_id]["favicon_fetching"] = feed.get("favicon_fetching")

    user_subs = UserSubscription.objects.filter(user=user, active=True).only("feed")
    sub_feed_ids = [s.feed_id for s in user_subs]

    if favicons_fetching:
        moved_feed_ids = [f for f in favicons_fetching if f not in sub_feed_ids]
        for moved_feed_id in moved_feed_ids:
            duplicate_feeds = DuplicateFeed.objects.filter(duplicate_feed_id=moved_feed_id)

            if duplicate_feeds and duplicate_feeds[0].feed.pk in feeds:
                feeds[moved_feed_id] = feeds[duplicate_feeds[0].feed_id]
                feeds[moved_feed_id]["dupe_feed_id"] = duplicate_feeds[0].feed_id

    if check_fetch_status:
        missing_feed_ids = list(set(feed_ids) - set(sub_feed_ids))
        if missing_feed_ids:
            duplicate_feeds = DuplicateFeed.objects.filter(duplicate_feed_id__in=missing_feed_ids)
            for duplicate_feed in duplicate_feeds:
                feeds[duplicate_feed.duplicate_feed_id] = {"id": duplicate_feed.feed_id}

    interactions_count = MInteraction.user_unread_count(user.pk)

    if True or settings.DEBUG or check_fetch_status:
        end = datetime.datetime.now()
        extra_fetch = ""
        if check_fetch_status or favicons_fetching:
            extra_fetch = "(%s/%s)" % (check_fetch_status, len(favicons_fetching))
        logging.user(
            request,
            "~FBRefreshing %s+%s feeds %s (%.4s/%.4s/%.4s)"
            % (
                len(list(feeds.keys())),
                len(list(social_feeds.keys())),
                extra_fetch,
                (checkpoint1 - start).total_seconds(),
                (checkpoint2 - start).total_seconds(),
                (end - start).total_seconds(),
            ),
        )

    MAnalyticsLoader.add(page_load=time.time() - start_time)

    return {
        "feeds": feeds,
        "social_feeds": social_feeds,
        "interactions_count": interactions_count,
    }


@json.json_view
def interactions_count(request):
    user = get_user(request)

    interactions_count = MInteraction.user_unread_count(user.pk)

    return {
        "interactions_count": interactions_count,
    }


@never_cache
@ajax_login_required
@json.json_view
def feed_unread_count(request):
    get_post = getattr(request, request.method)
    start = time.time()
    user = request.user
    feed_ids = get_post.getlist("feed_id") or get_post.getlist("feed_id[]")

    force = request.GET.get("force", False)
    social_feed_ids = [feed_id for feed_id in feed_ids if "social:" in feed_id]
    feed_ids = list(set(feed_ids) - set(social_feed_ids))

    feeds = {}
    if feed_ids:
        feeds = UserSubscription.feeds_with_updated_counts(user, feed_ids=feed_ids, force=force)

    social_feeds = {}
    if social_feed_ids:
        social_feeds = MSocialSubscription.feeds_with_updated_counts(user, social_feed_ids=social_feed_ids)

    if len(feed_ids) == 1:
        if settings.DEBUG:
            feed_title = Feed.get_by_id(feed_ids[0]).feed_title
        else:
            feed_title = feed_ids[0]
    elif len(social_feed_ids) == 1:
        social_profile = MSocialProfile.objects.get(user_id=social_feed_ids[0].replace("social:", ""))
        feed_title = social_profile.user.username if social_profile.user else "[deleted]"
    else:
        feed_title = "%s feeds" % (len(feeds) + len(social_feeds))
    logging.user(request, "~FBUpdating unread count on: %s" % feed_title)
    MAnalyticsLoader.add(page_load=time.time() - start)

    return {"feeds": feeds, "social_feeds": social_feeds}


def refresh_feed(request, feed_id):
    start = time.time()
    user = get_user(request)
    feed = get_object_or_404(Feed, pk=feed_id)

    feed = feed.update(force=True, compute_scores=False)
    usersub = UserSubscription.objects.get(user=user, feed=feed)
    usersub.calculate_feed_scores(silent=False)

    logging.user(request, "~FBRefreshing feed: %s" % feed)
    MAnalyticsLoader.add(page_load=time.time() - start)

    return load_single_feed(request, feed_id)


@never_cache
@json.json_view
def load_single_feed(request, feed_id):
    start = time.time()
    user = get_user(request)
    # offset                  = int(request.GET.get('offset', 0))
    # limit                   = int(request.GET.get('limit', 6))
    limit = 6
    page = int(request.GET.get("page", 1))
    delay = int(request.GET.get("delay", 0))
    offset = limit * (page - 1)
    order = request.GET.get("order", "newest")
    read_filter = request.GET.get("read_filter", "all")
    query = request.GET.get("query", "").strip()
    include_story_content = is_true(request.GET.get("include_story_content", True))
    include_hidden = is_true(request.GET.get("include_hidden", False))
    include_feeds = is_true(request.GET.get("include_feeds", False))
    message = None
    user_search = None

    dupe_feed_id = None
    user_profiles = []
    now = localtime_for_timezone(datetime.datetime.now(), user.profile.timezone)
    if not feed_id:
        raise Http404

    feed_address = request.GET.get("feed_address")
    feed = Feed.get_by_id(feed_id, feed_address=feed_address)
    if not feed:
        raise Http404

    try:
        usersub = UserSubscription.objects.get(user=user, feed=feed)
    except UserSubscription.DoesNotExist:
        usersub = None

    if feed.is_newsletter and not usersub:
        # User must be subscribed to a newsletter in order to read it
        raise Http404

    if feed.num_subscribers == 1 and not usersub and not user.is_staff:
        # This feed could be private so user must be subscribed in order to read it
        raise Http404

    if page > 400:
        logging.user(request, "~BR~FK~SBOver page 400 on single feed: %s" % page)
        raise Http404

    if query:
        if user.profile.is_premium:
            user_search = MUserSearch.get_user(user.pk)
            user_search.touch_search_date()
            stories = feed.find_stories(query, order=order, offset=offset, limit=limit)
        else:
            stories = []
            message = "You must be a premium subscriber to search."
    elif read_filter == "starred":
        mstories = MStarredStory.objects(user_id=user.pk, story_feed_id=feed_id).order_by(
            "%sstarred_date" % ("-" if order == "newest" else "")
        )[offset : offset + limit]
        stories = Feed.format_stories(mstories)
    elif usersub and read_filter == "unread":
        stories = usersub.get_stories(order=order, read_filter=read_filter, offset=offset, limit=limit)
    else:
        stories = feed.get_stories(offset, limit, order=order)

    checkpoint1 = time.time()

    try:
        stories, user_profiles = MSharedStory.stories_with_comments_and_profiles(stories, user.pk)
    except redis.ConnectionError:
        logging.user(request, "~BR~FK~SBRedis is unavailable for shared stories.")

    checkpoint2 = time.time()

    # Get intelligence classifier for user

    if usersub and usersub.is_trained:
        classifier_feeds = list(MClassifierFeed.objects(user_id=user.pk, feed_id=feed_id, social_user_id=0))
        classifier_authors = list(MClassifierAuthor.objects(user_id=user.pk, feed_id=feed_id))
        classifier_titles = list(MClassifierTitle.objects(user_id=user.pk, feed_id=feed_id))
        classifier_tags = list(MClassifierTag.objects(user_id=user.pk, feed_id=feed_id))
    else:
        classifier_feeds = []
        classifier_authors = []
        classifier_titles = []
        classifier_tags = []
    classifiers = get_classifiers_for_user(
        user,
        feed_id=feed_id,
        classifier_feeds=classifier_feeds,
        classifier_authors=classifier_authors,
        classifier_titles=classifier_titles,
        classifier_tags=classifier_tags,
    )
    checkpoint3 = time.time()

    unread_story_hashes = []
    if stories:
        if (read_filter == "all" or query) and usersub:
            unread_story_hashes = UserSubscription.story_hashes(
                user.pk,
                read_filter="unread",
                feed_ids=[usersub.feed_id],
                usersubs=[usersub],
                cutoff_date=user.profile.unread_cutoff,
            )
        story_hashes = [story["story_hash"] for story in stories if story["story_hash"]]
        starred_stories = MStarredStory.objects(
            user_id=user.pk, story_feed_id=feed.pk, story_hash__in=story_hashes
        ).hint([("user_id", 1), ("story_hash", 1)])
        shared_story_hashes = MSharedStory.check_shared_story_hashes(user.pk, story_hashes)
        shared_stories = []
        if shared_story_hashes:
            shared_stories = (
                MSharedStory.objects(user_id=user.pk, story_hash__in=shared_story_hashes)
                .hint([("story_hash", 1)])
                .only("story_hash", "shared_date", "comments")
            )
        starred_stories = dict([(story.story_hash, story) for story in starred_stories])
        shared_stories = dict(
            [
                (story.story_hash, dict(shared_date=story.shared_date, comments=story.comments))
                for story in shared_stories
            ]
        )

    checkpoint4 = time.time()

    for story in stories:
        if not include_story_content:
            del story["story_content"]
        story_date = localtime_for_timezone(story["story_date"], user.profile.timezone)
        nowtz = localtime_for_timezone(now, user.profile.timezone)
        story["short_parsed_date"] = format_story_link_date__short(story_date, nowtz)
        story["long_parsed_date"] = format_story_link_date__long(story_date, nowtz)
        if usersub:
            story["read_status"] = 1
            if not user.profile.is_archive and story["story_date"] < user.profile.unread_cutoff:
                story["read_status"] = 1
            elif (read_filter == "all" or query) and usersub:
                story["read_status"] = 1 if story["story_hash"] not in unread_story_hashes else 0
            elif read_filter == "unread" and usersub:
                story["read_status"] = 0
            if story["story_hash"] in starred_stories:
                story["starred"] = True
                starred_story = Feed.format_story(starred_stories[story["story_hash"]])
                starred_date = localtime_for_timezone(starred_story["starred_date"], user.profile.timezone)
                story["starred_date"] = format_story_link_date__long(starred_date, now)
                story["starred_timestamp"] = int(starred_date.timestamp())
                story["user_tags"] = starred_story["user_tags"]
                story["user_notes"] = starred_story["user_notes"]
                story["highlights"] = starred_story["highlights"]
            if story["story_hash"] in shared_stories:
                story["shared"] = True
                shared_date = localtime_for_timezone(
                    shared_stories[story["story_hash"]]["shared_date"], user.profile.timezone
                )
                story["shared_date"] = format_story_link_date__long(shared_date, now)
                story["shared_comments"] = strip_tags(shared_stories[story["story_hash"]]["comments"])
        else:
            story["read_status"] = 1
        story["intelligence"] = {
            "feed": apply_classifier_feeds(classifier_feeds, feed),
            "author": apply_classifier_authors(classifier_authors, story),
            "tags": apply_classifier_tags(classifier_tags, story),
            "title": apply_classifier_titles(classifier_titles, story),
        }
        story["score"] = UserSubscription.score_story(story["intelligence"])

    # Intelligence
    feed_tags = json.decode(feed.data.popular_tags) if feed.data.popular_tags else []
    feed_authors = json.decode(feed.data.popular_authors) if feed.data.popular_authors else []

    if include_feeds:
        feeds = Feed.objects.filter(pk__in=set([story["story_feed_id"] for story in stories]))
        feeds = [f.canonical(include_favicon=False) for f in feeds]

    if usersub:
        usersub.feed_opens += 1
        usersub.needs_unread_recalc = True
        try:
            usersub.save(update_fields=["feed_opens", "needs_unread_recalc"])
        except DatabaseError as e:
            logging.user(request, f"~BR~FK~SBNo changes in usersub, ignoring... {e}")

    diff1 = checkpoint1 - start
    diff2 = checkpoint2 - start
    diff3 = checkpoint3 - start
    diff4 = checkpoint4 - start
    timediff = time.time() - start
    last_update = relative_timesince(feed.last_update)
    time_breakdown = ""
    if timediff > 1 or settings.DEBUG:
        time_breakdown = "~SN~FR(~SB%.4s/%.4s/%.4s/%.4s~SN)" % (diff1, diff2, diff3, diff4)

    search_log = "~SN~FG(~SB%s~SN) " % query if query else ""
    logging.user(
        request,
        "~FYLoading feed: ~SB%s%s (%s/%s) %s%s"
        % (
            feed.feed_title[:22],
            ("~SN/p%s" % page) if page > 1 else "",
            order,
            read_filter,
            search_log,
            time_breakdown,
        ),
    )

    MAnalyticsLoader.add(page_load=timediff)
    if hasattr(request, "start_time"):
        seconds = time.time() - request.start_time
        RStats.add("page_load", duration=seconds)

    if not include_hidden:
        hidden_stories_removed = 0
        new_stories = []
        for story in stories:
            if story["score"] >= 0:
                new_stories.append(story)
            else:
                hidden_stories_removed += 1
        stories = new_stories

    data = dict(
        stories=stories,
        user_profiles=user_profiles,
        feed_tags=feed_tags,
        feed_authors=feed_authors,
        classifiers=classifiers,
        updated=last_update,
        user_search=user_search,
        feed_id=feed.pk,
        elapsed_time=round(float(timediff), 2),
        message=message,
    )

    if include_feeds:
        data["feeds"] = feeds
    if not include_hidden:
        data["hidden_stories_removed"] = hidden_stories_removed
    if dupe_feed_id:
        data["dupe_feed_id"] = dupe_feed_id
    if not usersub:
        data.update(feed.canonical())
    # if not usersub and feed.num_subscribers <= 1:
    #     data = dict(code=-1, message="You must be subscribed to this feed.")

    # time.sleep(random.randint(1, 3))
    if delay and user.is_staff:
        # time.sleep(random.randint(2, 7) / 10.0)
        time.sleep(delay)
    # if page == 1:
    #     time.sleep(1)
    # else:
    #     time.sleep(20)
    # if page == 2:
    #     assert False

    return data


def load_feed_page(request, feed_id):
    if not feed_id:
        raise Http404

    feed = Feed.get_by_id(feed_id)
    if feed and feed.has_page and not feed.has_page_exception:
        if settings.BACKED_BY_AWS.get("pages_on_node"):
            domain = Site.objects.get_current().domain
            url = "https://%s/original_page/%s" % (
                domain,
                feed.pk,
            )
            try:
                page_response = requests.get(url, verify=not settings.DEBUG)
            except requests.ConnectionError as e:
                logging.user(request, f"~FR~SBError loading original page: {url} {e}")
                page_response = None
            if page_response and page_response.status_code == 200:
                response = HttpResponse(page_response.content, content_type="text/html; charset=utf-8")
                response["Content-Encoding"] = "deflate"
                response["Last-Modified"] = page_response.headers.get("Last-modified")
                response["Etag"] = page_response.headers.get("Etag")
                response["Content-Length"] = str(len(page_response.content))
                logging.user(
                    request,
                    "~FYLoading original page (%s), proxied from node: ~SB%s bytes"
                    % (feed_id, len(page_response.content)),
                )
                return response

        if settings.BACKED_BY_AWS["pages_on_s3"] and feed.s3_page:
            if settings.PROXY_S3_PAGES:
                key = settings.S3_CONN.Bucket(settings.S3_PAGES_BUCKET_NAME).Object(key=feed.s3_pages_key)
                if key:
                    compressed_data = key.get()["Body"]
                    response = HttpResponse(compressed_data, content_type="text/html; charset=utf-8")
                    response["Content-Encoding"] = "gzip"

                    logging.user(
                        request, "~FYLoading original page, proxied: ~SB%s bytes" % (len(compressed_data))
                    )
                    return response
            else:
                logging.user(request, "~FYLoading original page, non-proxied")
                return HttpResponseRedirect("//%s/%s" % (settings.S3_PAGES_BUCKET_NAME, feed.s3_pages_key))

    data = MFeedPage.get_data(feed_id=feed_id)

    if not data or not feed or not feed.has_page or feed.has_page_exception:
        logging.user(request, "~FYLoading original page, ~FRmissing")
        return render(request, "static/404_original_page.xhtml", {}, content_type="text/html", status=404)

    logging.user(request, "~FYLoading original page, from the db")
    return HttpResponse(data, content_type="text/html; charset=utf-8")


@ratelimit(minutes=5, requests=50, use_path=True)
@json.json_view
def load_starred_stories(request):
    user = get_user(request)
    offset = int(request.GET.get("offset", 0))
    limit = int(request.GET.get("limit", 10))
    page = int(request.GET.get("page", 0))
    query = request.GET.get("query", "").strip()
    order = request.GET.get("order", "newest")
    tag = request.GET.get("tag")
    highlights = is_true(request.GET.get("highlights", False))
    story_hashes = request.GET.getlist("h") or request.GET.getlist("h[]")
    story_hashes = story_hashes[:100]
    version = int(request.GET.get("v", 1))
    now = localtime_for_timezone(datetime.datetime.now(), user.profile.timezone)
    message = None
    order_by = "-" if order == "newest" else ""
    if page:
        offset = limit * (page - 1)

    if query:
        # results = SearchStarredStory.query(user.pk, query)
        # story_ids = [result.db_id for result in results]
        if user.profile.is_premium:
            stories = MStarredStory.find_stories(
                query, user.pk, tag=tag, offset=offset, limit=limit, order=order
            )
        else:
            stories = []
            message = "You must be a premium subscriber to search."
    elif highlights:
        if user.profile.is_premium:
            mstories = MStarredStory.objects(
                user_id=user.pk, highlights__exists=True, __raw__={"$where": "this.highlights.length > 0"}
            ).order_by("%sstarred_date" % order_by)[offset : offset + limit]
            stories = Feed.format_stories(mstories)
        else:
            stories = []
            message = "You must be a premium subscriber to read through saved story highlights."
    elif tag:
        if user.profile.is_premium:
            mstories = MStarredStory.objects(user_id=user.pk, user_tags__contains=tag).order_by(
                "%sstarred_date" % order_by
            )[offset : offset + limit]
            stories = Feed.format_stories(mstories)
        else:
            stories = []
            message = "You must be a premium subscriber to read saved stories by tag."
    elif story_hashes:
        limit = 100
        mstories = MStarredStory.objects(user_id=user.pk, story_hash__in=story_hashes).order_by(
            "%sstarred_date" % order_by
        )[offset : offset + limit]
        stories = Feed.format_stories(mstories)
    else:
        mstories = MStarredStory.objects(user_id=user.pk).order_by("%sstarred_date" % order_by)[
            offset : offset + limit
        ]
        stories = Feed.format_stories(mstories)

    stories, user_profiles = MSharedStory.stories_with_comments_and_profiles(stories, user.pk, check_all=True)

    story_hashes = [story["story_hash"] for story in stories]
    story_feed_ids = list(set(s["story_feed_id"] for s in stories))
    usersub_ids = UserSubscription.objects.filter(user__pk=user.pk, feed__pk__in=story_feed_ids).values(
        "feed__pk"
    )
    usersub_ids = [us["feed__pk"] for us in usersub_ids]
    unsub_feed_ids = list(set(story_feed_ids).difference(set(usersub_ids)))
    unsub_feeds = Feed.objects.filter(pk__in=unsub_feed_ids)
    unsub_feeds = dict((feed.pk, feed.canonical(include_favicon=False)) for feed in unsub_feeds)
    for story in stories:
        if story["story_feed_id"] in unsub_feeds:
            continue
        duplicate_feed = DuplicateFeed.objects.filter(duplicate_feed_id=story["story_feed_id"])
        if not duplicate_feed:
            continue
        feed_id = duplicate_feed[0].feed_id
        try:
            saved_story = MStarredStory.objects.get(user_id=user.pk, story_hash=story["story_hash"])
            saved_story.feed_id = feed_id
            _, story_hash = MStory.split_story_hash(story["story_hash"])
            saved_story.story_hash = "%s:%s" % (feed_id, story_hash)
            saved_story.story_feed_id = feed_id
            story["story_hash"] = saved_story.story_hash
            story["story_feed_id"] = saved_story.story_feed_id
            saved_story.save()
            logging.user(
                request, "~FCSaving new feed for starred story: ~SB%s -> %s" % (story["story_hash"], feed_id)
            )
        except (MStarredStory.DoesNotExist, MStarredStory.MultipleObjectsReturned):
            logging.user(request, "~FCCan't find feed for starred story: ~SB%s" % (story["story_hash"]))
            continue

    shared_story_hashes = MSharedStory.check_shared_story_hashes(user.pk, story_hashes)
    shared_stories = []
    if shared_story_hashes:
        shared_stories = (
            MSharedStory.objects(user_id=user.pk, story_hash__in=shared_story_hashes)
            .hint([("story_hash", 1)])
            .only("story_hash", "shared_date", "comments")
        )
    shared_stories = dict(
        [
            (story.story_hash, dict(shared_date=story.shared_date, comments=story.comments))
            for story in shared_stories
        ]
    )

    nowtz = localtime_for_timezone(now, user.profile.timezone)
    for story in stories:
        story_date = localtime_for_timezone(story["story_date"], user.profile.timezone)
        story["short_parsed_date"] = format_story_link_date__short(story_date, nowtz)
        story["long_parsed_date"] = format_story_link_date__long(story_date, nowtz)
        starred_date = localtime_for_timezone(story["starred_date"], user.profile.timezone)
        story["starred_date"] = format_story_link_date__long(starred_date, nowtz)
        story["starred_timestamp"] = int(starred_date.timestamp())
        story["read_status"] = 1
        story["starred"] = True
        story["intelligence"] = {
            "feed": 1,
            "author": 0,
            "tags": 0,
            "title": 0,
        }
        if story["story_hash"] in shared_stories:
            story["shared"] = True
            story["shared_comments"] = strip_tags(shared_stories[story["story_hash"]]["comments"])

    search_log = "~SN~FG(~SB%s~SN)" % query if query else ""
    logging.user(request, "~FCLoading starred stories: ~SB%s stories %s" % (len(stories), search_log))

    return {
        "stories": stories,
        "user_profiles": user_profiles,
        "feeds": list(unsub_feeds.values()) if version == 2 else unsub_feeds,
        "message": message,
    }


@json.json_view
def starred_story_hashes(request):
    user = get_user(request)
    include_timestamps = is_true(request.GET.get("include_timestamps", False))

    mstories = (
        MStarredStory.objects(user_id=user.pk)
        .only("story_hash", "starred_date", "starred_updated")
        .order_by("-starred_date")
    )

    if include_timestamps:
        story_hashes = []
        for s in mstories:
            date = s.starred_date
            if s.starred_updated:
                date = s.starred_updated
            story_hashes.append((s.story_hash, date.strftime("%s")))
    else:
        story_hashes = [s.story_hash for s in mstories]

    logging.user(request, "~FYLoading ~FCstarred story hashes~FY: %s story hashes" % (len(story_hashes)))

    return dict(starred_story_hashes=story_hashes)


def starred_stories_rss_feed(request, user_id, secret_token):
    return starred_stories_rss_feed_tag(request, user_id, secret_token, tag_slug=None)


def starred_stories_rss_feed_tag(request, user_id, secret_token, tag_slug):
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        raise Http404

    if tag_slug:
        try:
            tag_counts = MStarredStoryCounts.objects.get(user_id=user_id, slug=tag_slug)
        except MStarredStoryCounts.MultipleObjectsReturned:
            tag_counts = MStarredStoryCounts.objects(user_id=user_id, slug=tag_slug).first()
        except MStarredStoryCounts.DoesNotExist:
            raise Http404
    else:
        _, starred_count = MStarredStoryCounts.user_counts(user.pk, include_total=True)

    data = {}
    if tag_slug:
        data["title"] = "Saved Stories - %s" % tag_counts.tag
    else:
        data["title"] = "Saved Stories"
    data["link"] = "%s%s" % (
        settings.NEWSBLUR_URL,
        reverse("saved-stories-tag", kwargs=dict(tag_name=tag_slug)),
    )
    if tag_slug:
        data["description"] = 'Stories saved by %s on NewsBlur with the tag "%s".' % (
            user.username,
            tag_counts.tag,
        )
    else:
        data["description"] = "Stories saved by %s on NewsBlur." % (user.username)
    data["lastBuildDate"] = datetime.datetime.utcnow()
    data["generator"] = "NewsBlur - %s" % settings.NEWSBLUR_URL
    data["docs"] = None
    data["author_name"] = user.username
    data["feed_url"] = "%s%s" % (
        settings.NEWSBLUR_URL,
        reverse(
            "starred-stories-rss-feed-tag",
            kwargs=dict(user_id=user_id, secret_token=secret_token, tag_slug=tag_slug),
        ),
    )
    rss = feedgenerator.Atom1Feed(**data)

    if not tag_slug or not tag_counts.tag:
        starred_stories = MStarredStory.objects(user_id=user.pk).order_by("-starred_date").limit(25)
    elif tag_counts.is_highlights:
        starred_stories = (
            MStarredStory.objects(
                user_id=user.pk, highlights__exists=True, __raw__={"$where": "this.highlights.length > 0"}
            )
            .order_by("-starred_date")
            .limit(25)
        )
    else:
        starred_stories = (
            MStarredStory.objects(user_id=user.pk, user_tags__contains=tag_counts.tag)
            .order_by("-starred_date")
            .limit(25)
        )

    starred_stories = Feed.format_stories(starred_stories)

    for starred_story in starred_stories:
        story_data = {
            "title": smart_str(starred_story["story_title"]),
            "link": starred_story["story_permalink"],
            "description": smart_str(starred_story["story_content"]),
            "author_name": starred_story["story_authors"],
            "categories": starred_story["story_tags"],
            "unique_id": starred_story["story_permalink"],
            "pubdate": starred_story["starred_date"],
        }
        rss.add_item(**story_data)

    logging.user(
        request,
        "~FBGenerating ~SB%s~SN's saved story RSS feed (%s, %s stories): ~FM%s"
        % (
            user.username,
            tag_counts.tag if tag_slug else "[All stories]",
            tag_counts.count if tag_slug else starred_count,
            request.META.get("HTTP_USER_AGENT", "")[:24],
        ),
    )
    return HttpResponse(rss.writeString("utf-8"), content_type="application/rss+xml")


def folder_rss_feed(request, user_id, secret_token, unread_filter, folder_slug):
    domain = Site.objects.get_current().domain
    date_hack_2023 = datetime.datetime.now() > datetime.datetime(2023, 7, 1)
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        raise Http404

    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=user)
    feed_ids, folder_title = user_sub_folders.feed_ids_under_folder_slug(folder_slug)

    usersubs = UserSubscription.subs_for_feeds(user.pk, feed_ids=feed_ids)
    if feed_ids and ((user.profile.is_archive and date_hack_2023) or (not date_hack_2023)):
        params = {
            "user_id": user.pk,
            "feed_ids": feed_ids,
            "offset": 0,
            "limit": 20,
            "order": "newest",
            "read_filter": "all",
            "cache_prefix": "RSS:",
        }
        story_hashes, unread_feed_story_hashes = UserSubscription.feed_stories(**params)
    else:
        story_hashes = []

    mstories = MStory.objects(story_hash__in=story_hashes).order_by("-story_date")
    stories = Feed.format_stories(mstories)

    filtered_stories = []
    found_feed_ids = list(set([story["story_feed_id"] for story in stories]))
    trained_feed_ids = [sub.feed_id for sub in usersubs if sub.is_trained]
    found_trained_feed_ids = list(set(trained_feed_ids) & set(found_feed_ids))
    if found_trained_feed_ids:
        classifier_feeds = list(
            MClassifierFeed.objects(user_id=user.pk, feed_id__in=found_trained_feed_ids, social_user_id=0)
        )
        classifier_authors = list(
            MClassifierAuthor.objects(user_id=user.pk, feed_id__in=found_trained_feed_ids)
        )
        classifier_titles = list(
            MClassifierTitle.objects(user_id=user.pk, feed_id__in=found_trained_feed_ids)
        )
        classifier_tags = list(MClassifierTag.objects(user_id=user.pk, feed_id__in=found_trained_feed_ids))
    else:
        classifier_feeds = []
        classifier_authors = []
        classifier_titles = []
        classifier_tags = []

    sort_classifiers_by_feed(
        user=user,
        feed_ids=found_feed_ids,
        classifier_feeds=classifier_feeds,
        classifier_authors=classifier_authors,
        classifier_titles=classifier_titles,
        classifier_tags=classifier_tags,
    )
    for story in stories:
        story["intelligence"] = {
            "feed": apply_classifier_feeds(classifier_feeds, story["story_feed_id"]),
            "author": apply_classifier_authors(classifier_authors, story),
            "tags": apply_classifier_tags(classifier_tags, story),
            "title": apply_classifier_titles(classifier_titles, story),
        }
        story["score"] = UserSubscription.score_story(story["intelligence"])
        if unread_filter == "focus" and story["score"] >= 1:
            filtered_stories.append(story)
        elif unread_filter == "unread" and story["score"] >= 0:
            filtered_stories.append(story)

    stories = filtered_stories

    data = {}
    data["title"] = "%s from %s (%s sites)" % (folder_title, user.username, len(feed_ids))
    data["link"] = "https://%s%s" % (domain, reverse("folder", kwargs=dict(folder_name=folder_title)))
    data["description"] = "Unread stories in %s on NewsBlur. From %s's account and contains %s sites." % (
        folder_title,
        user.username,
        len(feed_ids),
    )
    data["lastBuildDate"] = datetime.datetime.utcnow()
    data["generator"] = "NewsBlur - %s" % settings.NEWSBLUR_URL
    data["docs"] = None
    data["author_name"] = user.username
    data["feed_url"] = "https://%s%s" % (
        domain,
        reverse(
            "folder-rss-feed",
            kwargs=dict(
                user_id=user_id,
                secret_token=secret_token,
                unread_filter=unread_filter,
                folder_slug=folder_slug,
            ),
        ),
    )
    rss = feedgenerator.Atom1Feed(**data)

    for story in stories:
        feed = Feed.get_by_id(story["story_feed_id"])
        feed_title = feed.feed_title if feed else ""
        try:
            usersub = UserSubscription.objects.get(user=user, feed=feed)
            if usersub.user_title:
                feed_title = usersub.user_title
        except UserSubscription.DoesNotExist:
            usersub = None

        story_content = """%s<br><br><img src="//%s/rss_feeds/icon/%s" width="16" height="16"> %s""" % (
            smart_str(story["story_content"]),
            Site.objects.get_current().domain,
            story["story_feed_id"],
            feed_title,
        )
        story_content = re.sub(r"[\x00-\x08\x0B-\x0C\x0E-\x1F]", "", story_content)
        story_title = "%s%s" % (("%s: " % feed_title) if feed_title else "", story["story_title"])
        story_data = {
            "title": story_title,
            "link": story["story_permalink"],
            "description": story_content,
            "categories": story["story_tags"],
            "unique_id": "https://%s/site/%s/%s/" % (domain, story["story_feed_id"], story["guid_hash"]),
            "pubdate": localtime_for_timezone(story["story_date"], user.profile.timezone),
        }
        if story["story_authors"]:
            story_data["author_name"] = story["story_authors"]
        rss.add_item(**story_data)

    # TODO: Remove below date hack to accomodate users who paid for premium but want folder rss
    if not user.profile.is_archive and date_hack_2023:
        story_data = {
            "title": "You must have a premium archive subscription on NewsBlur to have RSS feeds for folders.",
            "link": "https://%s/?next=premium" % domain,
            "description": "You must have a premium archive subscription on NewsBlur to have RSS feeds for folders.",
            "unique_id": "https://%s/premium_only" % domain,
            "pubdate": localtime_for_timezone(datetime.datetime.now(), user.profile.timezone),
        }
        rss.add_item(**story_data)

    logging.user(
        request,
        "~FBGenerating ~SB%s~SN's folder RSS feed (%s, %s stories): ~FM%s"
        % (user.username, folder_title, len(stories), request.META.get("HTTP_USER_AGENT", "")[:24]),
    )
    return HttpResponse(rss.writeString("utf-8"), content_type="application/rss+xml")


@json.json_view
def load_read_stories(request):
    user = get_user(request)
    offset = int(request.GET.get("offset", 0))
    limit = int(request.GET.get("limit", 10))
    page = int(request.GET.get("page", 0))
    order = request.GET.get("order", "newest")
    query = request.GET.get("query", "").strip()
    now = localtime_for_timezone(datetime.datetime.now(), user.profile.timezone)
    message = None
    if page:
        offset = limit * (page - 1)

    if query:
        stories = []
        message = "Not implemented yet."
        # if user.profile.is_premium:
        #     stories = MStarredStory.find_stories(query, user.pk, offset=offset, limit=limit)
        # else:
        #     stories = []
        #     message = "You must be a premium subscriber to search."
    else:
        story_hashes = RUserStory.get_read_stories(user.pk, offset=offset, limit=limit, order=order)
        mstories = MStory.objects(story_hash__in=story_hashes)
        stories = Feed.format_stories(mstories)
        stories = sorted(
            stories,
            key=lambda story: story_hashes.index(story["story_hash"]),
            reverse=bool(order == "oldest"),
        )

    stories, user_profiles = MSharedStory.stories_with_comments_and_profiles(stories, user.pk, check_all=True)

    story_hashes = [story["story_hash"] for story in stories]
    story_feed_ids = list(set(s["story_feed_id"] for s in stories))
    usersub_ids = UserSubscription.objects.filter(user__pk=user.pk, feed__pk__in=story_feed_ids).values(
        "feed__pk"
    )
    usersub_ids = [us["feed__pk"] for us in usersub_ids]
    unsub_feed_ids = list(set(story_feed_ids).difference(set(usersub_ids)))
    unsub_feeds = Feed.objects.filter(pk__in=unsub_feed_ids)
    unsub_feeds = [feed.canonical(include_favicon=False) for feed in unsub_feeds]

    shared_stories = (
        MSharedStory.objects(user_id=user.pk, story_hash__in=story_hashes)
        .hint([("story_hash", 1)])
        .only("story_hash", "shared_date", "comments")
    )
    shared_stories = dict(
        [
            (story.story_hash, dict(shared_date=story.shared_date, comments=story.comments))
            for story in shared_stories
        ]
    )
    starred_stories = MStarredStory.objects(user_id=user.pk, story_hash__in=story_hashes).hint(
        [("user_id", 1), ("story_hash", 1)]
    )
    starred_stories = dict([(story.story_hash, story) for story in starred_stories])

    nowtz = localtime_for_timezone(now, user.profile.timezone)
    for story in stories:
        story_date = localtime_for_timezone(story["story_date"], user.profile.timezone)
        story["short_parsed_date"] = format_story_link_date__short(story_date, nowtz)
        story["long_parsed_date"] = format_story_link_date__long(story_date, nowtz)
        story["read_status"] = 1
        story["intelligence"] = {
            "feed": 1,
            "author": 0,
            "tags": 0,
            "title": 0,
        }
        if story["story_hash"] in starred_stories:
            story["starred"] = True
            starred_story = Feed.format_story(starred_stories[story["story_hash"]])
            starred_date = localtime_for_timezone(starred_story["starred_date"], user.profile.timezone)
            story["starred_date"] = format_story_link_date__long(starred_date, now)
            story["starred_timestamp"] = int(starred_date.timestamp())
        if story["story_hash"] in shared_stories:
            story["shared"] = True
            story["shared_comments"] = strip_tags(shared_stories[story["story_hash"]]["comments"])

    search_log = "~SN~FG(~SB%s~SN)" % query if query else ""
    logging.user(request, "~FCLoading read stories: ~SB%s stories %s" % (len(stories), search_log))

    return {
        "stories": stories,
        "user_profiles": user_profiles,
        "feeds": unsub_feeds,
        "message": message,
    }


@json.json_view
def load_river_stories__redis(request):
    # get_post is request.REQUEST, since this endpoint needs to handle either
    # GET or POST requests, since the parameters for this endpoint can be
    # very long, at which point the max size of a GET url request is exceeded.
    get_post = getattr(request, request.method)
    limit = int(get_post.get("limit", 12))
    start = time.time()
    user = get_user(request)
    message = None
    feed_ids = get_post.getlist("feeds") or get_post.getlist("feeds[]")
    feed_ids = [int(feed_id) for feed_id in feed_ids if feed_id]
    if not feed_ids:
        feed_ids = get_post.getlist("f") or get_post.getlist("f[]")
        feed_ids = [int(feed_id) for feed_id in get_post.getlist("f") if feed_id]
    story_hashes = get_post.getlist("h") or get_post.getlist("h[]")
    story_hashes = story_hashes[:100]
    requested_hashes = len(story_hashes)
    original_feed_ids = list(feed_ids)
    page = int(get_post.get("page", 1))
    order = get_post.get("order", "newest")
    read_filter = get_post.get("read_filter", "unread")
    query = get_post.get("query", "").strip()
    include_hidden = is_true(get_post.get("include_hidden", False))
    include_feeds = is_true(get_post.get("include_feeds", False))
    on_dashboard = is_true(get_post.get("dashboard", False)) or is_true(get_post.get("on_dashboard", False))
    infrequent = is_true(get_post.get("infrequent", False))
    if infrequent:
        infrequent = get_post.get("infrequent")
    now = localtime_for_timezone(datetime.datetime.now(), user.profile.timezone)
    usersubs = []
    code = 1
    user_search = None
    offset = (page - 1) * limit
    story_date_order = "%sstory_date" % ("" if order == "oldest" else "-")

    if user.pk == 86178:
        # Disable Michael_Novakhov account
        logging.user(request, "~FCLoading ~FMMichael_Novakhov~SN's river, resource usage too high, ignoring.")
        return HttpResponse("Resource usage too high", status=429)

    if infrequent:
        feed_ids = Feed.low_volume_feeds(feed_ids, stories_per_month=infrequent)

    if story_hashes:
        unread_feed_story_hashes = None
        read_filter = "all"
        mstories = MStory.objects(story_hash__in=story_hashes).order_by(story_date_order)
        stories = Feed.format_stories(mstories)
    elif query:
        if user.profile.is_premium:
            user_search = MUserSearch.get_user(user.pk)
            user_search.touch_search_date()
            usersubs = UserSubscription.subs_for_feeds(user.pk, feed_ids=feed_ids, read_filter="all")
            feed_ids = [sub.feed_id for sub in usersubs]
            if infrequent:
                feed_ids = Feed.low_volume_feeds(feed_ids, stories_per_month=infrequent)
            stories = Feed.find_feed_stories(feed_ids, query, order=order, offset=offset, limit=limit)
            mstories = stories
            unread_feed_story_hashes = UserSubscription.story_hashes(
                user.pk,
                feed_ids=feed_ids,
                read_filter="unread",
                order=order,
                cutoff_date=user.profile.unread_cutoff,
            )
        else:
            stories = []
            mstories = []
            message = "You must be a premium subscriber to search."
    elif read_filter == "starred":
        mstories = MStarredStory.objects(user_id=user.pk, story_feed_id__in=feed_ids).order_by(
            "%sstarred_date" % ("-" if order == "newest" else "")
        )[offset : offset + limit]
        stories = Feed.format_stories(mstories)
    else:
        usersubs = UserSubscription.subs_for_feeds(user.pk, feed_ids=feed_ids, read_filter=read_filter)
        all_feed_ids = [f for f in feed_ids]
        feed_ids = [sub.feed_id for sub in usersubs]
        if infrequent:
            feed_ids = Feed.low_volume_feeds(feed_ids, stories_per_month=infrequent)
        if feed_ids:
            params = {
                "user_id": user.pk,
                "feed_ids": feed_ids,
                "all_feed_ids": all_feed_ids,
                "offset": offset,
                "limit": limit,
                "order": order,
                "read_filter": read_filter,
                "usersubs": usersubs,
                "cutoff_date": user.profile.unread_cutoff,
                "cache_prefix": "dashboard:" if on_dashboard else "",
            }
            story_hashes, unread_feed_story_hashes = UserSubscription.feed_stories(**params)
        else:
            story_hashes = []
            unread_feed_story_hashes = []

        mstories = MStory.objects(story_hash__in=story_hashes[:limit]).order_by(story_date_order)
        stories = Feed.format_stories(mstories)

    found_feed_ids = list(set([story["story_feed_id"] for story in stories]))
    stories, user_profiles = MSharedStory.stories_with_comments_and_profiles(stories, user.pk)

    if not usersubs:
        usersubs = UserSubscription.subs_for_feeds(user.pk, feed_ids=found_feed_ids, read_filter=read_filter)

    trained_feed_ids = [sub.feed_id for sub in usersubs if sub.is_trained]
    found_trained_feed_ids = list(set(trained_feed_ids) & set(found_feed_ids))

    # Find starred stories
    if found_feed_ids:
        if read_filter == "starred":
            starred_stories = mstories
        else:
            story_hashes = [s["story_hash"] for s in stories]
            starred_stories = MStarredStory.objects(user_id=user.pk, story_hash__in=story_hashes)
        starred_stories = dict(
            [
                (
                    story.story_hash,
                    dict(
                        starred_date=story.starred_date,
                        user_tags=story.user_tags,
                        highlights=story.highlights,
                        user_notes=story.user_notes,
                    ),
                )
                for story in starred_stories
            ]
        )
    else:
        starred_stories = {}

    # Intelligence classifiers for all feeds involved
    if found_trained_feed_ids:
        classifier_feeds = list(
            MClassifierFeed.objects(user_id=user.pk, feed_id__in=found_trained_feed_ids, social_user_id=0)
        )
        classifier_authors = list(
            MClassifierAuthor.objects(user_id=user.pk, feed_id__in=found_trained_feed_ids)
        )
        classifier_titles = list(
            MClassifierTitle.objects(user_id=user.pk, feed_id__in=found_trained_feed_ids)
        )
        classifier_tags = list(MClassifierTag.objects(user_id=user.pk, feed_id__in=found_trained_feed_ids))
    else:
        classifier_feeds = []
        classifier_authors = []
        classifier_titles = []
        classifier_tags = []
    classifiers = sort_classifiers_by_feed(
        user=user,
        feed_ids=found_feed_ids,
        classifier_feeds=classifier_feeds,
        classifier_authors=classifier_authors,
        classifier_titles=classifier_titles,
        classifier_tags=classifier_tags,
    )

    # Just need to format stories
    nowtz = localtime_for_timezone(now, user.profile.timezone)
    for story in stories:
        if read_filter == "starred":
            story["read_status"] = 1
        else:
            story["read_status"] = 0
        if read_filter == "all" or query:
            if unread_feed_story_hashes is not None and story["story_hash"] not in unread_feed_story_hashes:
                story["read_status"] = 1
        story_date = localtime_for_timezone(story["story_date"], user.profile.timezone)
        story["short_parsed_date"] = format_story_link_date__short(story_date, nowtz)
        story["long_parsed_date"] = format_story_link_date__long(story_date, nowtz)
        if story["story_hash"] in starred_stories:
            story["starred"] = True
            starred_date = localtime_for_timezone(
                starred_stories[story["story_hash"]]["starred_date"], user.profile.timezone
            )
            story["starred_date"] = format_story_link_date__long(starred_date, now)
            story["starred_timestamp"] = int(starred_date.timestamp())
            story["user_tags"] = starred_stories[story["story_hash"]]["user_tags"]
            story["user_notes"] = starred_stories[story["story_hash"]]["user_notes"]
            story["highlights"] = starred_stories[story["story_hash"]]["highlights"]
        story["intelligence"] = {
            "feed": apply_classifier_feeds(classifier_feeds, story["story_feed_id"]),
            "author": apply_classifier_authors(classifier_authors, story),
            "tags": apply_classifier_tags(classifier_tags, story),
            "title": apply_classifier_titles(classifier_titles, story),
        }
        story["score"] = UserSubscription.score_story(story["intelligence"])

    if include_feeds:
        feeds = Feed.objects.filter(pk__in=set([story["story_feed_id"] for story in stories]))
        feeds = [feed.canonical(include_favicon=False) for feed in feeds]

    if not user.profile.is_premium and not include_feeds:
        message = "The full River of News is a premium feature."
        code = 0
        # if page > 1:
        #     stories = []
        # else:
        #     stories = stories[:5]
    if not include_hidden:
        hidden_stories_removed = 0
        new_stories = []
        for story in stories:
            if story["score"] >= 0:
                new_stories.append(story)
            else:
                hidden_stories_removed += 1
        stories = new_stories

    # if page > 1:
    #     import random
    #     time.sleep(random.randint(10, 16))

    diff = time.time() - start
    timediff = round(float(diff), 2)
    if requested_hashes and story_hashes:
        logging.user(
            request,
            "~FB%sLoading ~FC%s~FB stories: %s%s"
            % (
                "~FBAuto-" if on_dashboard else "",
                requested_hashes,
                story_hashes[:3],
                f"...(+{len(story_hashes)-3})" if len(story_hashes) > 3 else "",
            ),
        )
    else:
        logging.user(
            request,
            "~FY%sLoading ~FC%sriver stories~FY: ~SBp%s~SN (%s/%s "
            "stories, ~SN%s/%s/%s feeds, %s/%s)"
            % (
                "~FCAuto-" if on_dashboard else "",
                "~FB~SBinfrequent~SN~FC " if infrequent else "",
                page,
                len(stories),
                len(mstories),
                len(found_feed_ids),
                len(feed_ids),
                len(original_feed_ids),
                order,
                read_filter,
            ),
        )

    if not on_dashboard and not (requested_hashes and story_hashes):
        MAnalyticsLoader.add(page_load=diff)  # Only count full pages, not individual stories
        if hasattr(request, "start_time"):
            seconds = time.time() - request.start_time
            RStats.add("page_load", duration=seconds)

    data = dict(
        code=code,
        message=message,
        stories=stories,
        classifiers=classifiers,
        elapsed_time=timediff,
        user_search=user_search,
        user_profiles=user_profiles,
    )

    if include_feeds:
        data["feeds"] = feeds
    if not include_hidden:
        data["hidden_stories_removed"] = hidden_stories_removed

    return data


@json.json_view
def load_river_stories_widget(request):
    logging.user(request, "Widget load")
    river_stories_data = json.decode(load_river_stories__redis(request).content)
    timeout = 3
    start = time.time()

    def load_url(url):
        original_url = url
        url = urllib.parse.urljoin(settings.NEWSBLUR_URL, url)
        scontext = ssl.SSLContext(ssl.PROTOCOL_TLS)
        scontext.verify_mode = ssl.VerifyMode.CERT_NONE
        conn = None
        try:
            conn = urllib.request.urlopen(url, context=scontext, timeout=timeout)
        except (urllib.error.URLError, socket.timeout, UnicodeEncodeError, http.client.InvalidURL):
            pass
        if not conn:
            # logging.user(request.user, '"%s" wasn\'t fetched, trying again: %s' % (url, e))
            url = url.replace("localhost", "haproxy")
            try:
                conn = urllib.request.urlopen(url, context=scontext, timeout=timeout)
            except (urllib.error.HTTPError, urllib.error.URLError, socket.timeout) as e:
                logging.user(
                    request.user, '~FB"%s" ~FRnot fetched~FB in %ss: ~SB%s' % (url, (time.time() - start), e)
                )
                return None

        data = conn.read()
        if not url.startswith("data:"):
            data = base64.b64encode(data).decode("utf-8")
        logging.user(request.user, '~FB"%s" ~SBfetched~SN in ~SB%ss' % (url, (time.time() - start)))
        return dict(url=original_url, data=data)

    # Find the image thumbnails and download in parallel
    thumbnail_urls = []
    for story in river_stories_data["stories"]:
        thumbnail_values = list(story["secure_image_thumbnails"].values())
        for thumbnail_value in thumbnail_values:
            if "data:" in thumbnail_value:
                continue
            thumbnail_urls.append(thumbnail_value)
            break

    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
        pages = executor.map(load_url, thumbnail_urls)

    # Reassemble thumbnails back into stories
    thumbnail_data = dict()
    for page in pages:
        if not page:
            continue
        thumbnail_data[page["url"]] = page["data"]
    for story in river_stories_data["stories"]:
        thumbnail_values = list(story["secure_image_thumbnails"].values())
        if thumbnail_values and thumbnail_values[0] in thumbnail_data:
            page_url = thumbnail_values[0]
            story["select_thumbnail_data"] = thumbnail_data[page_url]

    logging.user(request, ("Elapsed Time: %ss" % (time.time() - start)))

    return river_stories_data


@json.json_view
def complete_river(request):
    user = get_user(request)
    feed_ids = request.POST.getlist("feeds") or request.POST.getlist("feeds[]")
    feed_ids = [int(feed_id) for feed_id in feed_ids if feed_id and feed_id.isnumeric()]
    page = int(request.POST.get("page", 1))
    read_filter = request.POST.get("read_filter", "unread")
    stories_truncated = 0

    usersubs = UserSubscription.subs_for_feeds(user.pk, feed_ids=feed_ids, read_filter=read_filter)
    feed_ids = [sub.feed_id for sub in usersubs]
    if feed_ids:
        stories_truncated = UserSubscription.truncate_river(
            user.pk, feed_ids, read_filter, cache_prefix="dashboard:"
        )

    if page >= 1:
        logging.user(
            request,
            "~FC~BBRiver complete on page ~SB%s~SN, truncating ~SB%s~SN stories from ~SB%s~SN feeds"
            % (page, stories_truncated, len(feed_ids)),
        )

    return dict(code=1, message="Truncated %s stories from %s" % (stories_truncated, len(feed_ids)))


@json.json_view
def unread_story_hashes(request):
    user = get_user(request)
    feed_ids = request.GET.getlist("feed_id") or request.GET.getlist("feed_id[]")
    feed_ids = [int(feed_id) for feed_id in feed_ids if feed_id]
    include_timestamps = is_true(request.GET.get("include_timestamps", False))
    order = request.GET.get("order", "newest")
    read_filter = request.GET.get("read_filter", "unread")

    story_hashes = UserSubscription.story_hashes(
        user.pk,
        feed_ids=feed_ids,
        order=order,
        read_filter=read_filter,
        include_timestamps=include_timestamps,
        group_by_feed=True,
        cutoff_date=user.profile.unread_cutoff,
    )

    logging.user(
        request,
        "~FYLoading ~FCunread story hashes~FY: ~SB%s feeds~SN (%s story hashes)"
        % (len(feed_ids), len(story_hashes)),
    )
    return dict(unread_feed_story_hashes=story_hashes)


@ajax_login_required
@json.json_view
def mark_all_as_read(request):
    code = 1
    try:
        days = int(request.POST.get("days", 0))
    except ValueError:
        return dict(code=-1, message="Days parameter must be an integer, not: %s" % request.POST.get("days"))
    read_date = datetime.datetime.utcnow() - datetime.timedelta(days=days)

    feeds = UserSubscription.objects.filter(user=request.user)

    infrequent = is_true(request.POST.get("infrequent", False))
    if infrequent:
        infrequent = request.POST.get("infrequent")
        feed_ids = Feed.low_volume_feeds([usersub.feed.pk for usersub in feeds], stories_per_month=infrequent)
        feeds = UserSubscription.objects.filter(user=request.user, feed_id__in=feed_ids)

    socialsubs = MSocialSubscription.objects.filter(user_id=request.user.pk)
    for subtype in [feeds, socialsubs]:
        for sub in subtype:
            if days == 0:
                sub.mark_feed_read()
            else:
                if sub.mark_read_date < read_date:
                    sub.needs_unread_recalc = True
                    sub.mark_read_date = read_date
                    sub.save()

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, "reload:feeds")

    logging.user(
        request,
        "~FMMarking %s as read: ~SB%s days"
        % (
            ("all" if not infrequent else "infrequent stories"),
            days,
        ),
    )
    return dict(code=code)


@ajax_login_required
@json.json_view
def mark_story_as_read(request):
    story_ids = request.POST.getlist("story_id") or request.POST.getlist("story_id[]")
    try:
        feed_id = int(get_argument_or_404(request, "feed_id"))
    except ValueError:
        return dict(code=-1, errors=["You must pass a valid feed_id: %s" % request.POST.get("feed_id")])

    try:
        usersub = UserSubscription.objects.select_related("feed").get(user=request.user, feed=feed_id)
    except Feed.DoesNotExist:
        duplicate_feed = DuplicateFeed.objects.filter(duplicate_feed_id=feed_id)
        if duplicate_feed:
            feed_id = duplicate_feed[0].feed_id
            try:
                usersub = UserSubscription.objects.get(user=request.user, feed=duplicate_feed[0].feed)
            except Feed.DoesNotExist:
                return dict(code=-1, errors=["No feed exists for feed_id %d." % feed_id])
        else:
            return dict(code=-1, errors=["No feed exists for feed_id %d." % feed_id])
    except UserSubscription.DoesNotExist:
        usersub = None

    if usersub:
        data = usersub.mark_story_ids_as_read(story_ids, request=request)
    else:
        data = dict(code=-1, errors=["User is not subscribed to this feed."])

    return data


@ajax_login_required
@json.json_view
def mark_story_hashes_as_read(request):
    retrying_failed = is_true(request.POST.get("retrying_failed", False))
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    try:
        story_hashes = request.POST.getlist("story_hash") or request.POST.getlist("story_hash[]")
    except UnreadablePostError:
        return dict(code=-1, message="Missing `story_hash` list parameter.")

    feed_ids, friend_ids = RUserStory.mark_story_hashes_read(
        request.user.pk, story_hashes, username=request.user.username
    )

    if request.user.profile.is_archive:
        RUserUnreadStory.mark_read(request.user.pk, story_hashes)

    if friend_ids:
        socialsubs = MSocialSubscription.objects.filter(
            user_id=request.user.pk, subscription_user_id__in=friend_ids
        )
        for socialsub in socialsubs:
            if not socialsub.needs_unread_recalc:
                socialsub.needs_unread_recalc = True
                socialsub.save()
            r.publish(request.user.username, "social:%s" % socialsub.subscription_user_id)

    # Also count on original subscription
    for feed_id in feed_ids:
        usersubs = UserSubscription.objects.filter(user=request.user.pk, feed=feed_id)
        if usersubs:
            usersub = usersubs[0]
            usersub.last_read_date = datetime.datetime.now()
            if not usersub.needs_unread_recalc:
                usersub.needs_unread_recalc = True
                usersub.save(update_fields=["needs_unread_recalc", "last_read_date"])
            else:
                usersub.save(update_fields=["last_read_date"])
            r.publish(request.user.username, "feed:%s" % feed_id)

    hash_count = len(story_hashes)
    logging.user(
        request,
        "~FYRead %s %s: %s %s"
        % (
            hash_count,
            "story" if hash_count == 1 else "stories",
            story_hashes,
            "(retrying failed)" if retrying_failed else "",
        ),
    )

    return dict(code=1, story_hashes=story_hashes, feed_ids=feed_ids, friend_user_ids=friend_ids)


@ajax_login_required
@json.json_view
def mark_feed_stories_as_read(request):
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    feeds_stories = request.POST.get("feeds_stories", "{}")
    feeds_stories = json.decode(feeds_stories)
    data = {"code": -1, "message": "Nothing was marked as read"}

    for feed_id, story_ids in list(feeds_stories.items()):
        try:
            feed_id = int(feed_id)
        except ValueError:
            continue
        try:
            usersub = UserSubscription.objects.select_related("feed").get(user=request.user, feed=feed_id)
            data = usersub.mark_story_ids_as_read(story_ids, request=request)
        except UserSubscription.DoesNotExist:
            return dict(code=-1, error="You are not subscribed to this feed_id: %d" % feed_id)
        except Feed.DoesNotExist:
            duplicate_feed = DuplicateFeed.objects.filter(duplicate_feed_id=feed_id)
            try:
                if not duplicate_feed:
                    raise Feed.DoesNotExist
                usersub = UserSubscription.objects.get(user=request.user, feed=duplicate_feed[0].feed)
                data = usersub.mark_story_ids_as_read(story_ids, request=request)
            except (UserSubscription.DoesNotExist, Feed.DoesNotExist):
                return dict(code=-1, error="No feed exists for feed_id: %d" % feed_id)

        r.publish(request.user.username, "feed:%s" % feed_id)

    return data


@ajax_login_required
@json.json_view
def mark_social_stories_as_read(request):
    code = 1
    errors = []
    data = {}
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    users_feeds_stories = request.POST.get("users_feeds_stories", "{}")
    users_feeds_stories = json.decode(users_feeds_stories)

    for social_user_id, feeds in list(users_feeds_stories.items()):
        for feed_id, story_ids in list(feeds.items()):
            feed_id = int(feed_id)
            try:
                socialsub = MSocialSubscription.objects.get(
                    user_id=request.user.pk, subscription_user_id=social_user_id
                )
                data = socialsub.mark_story_ids_as_read(story_ids, feed_id, request=request)
            except OperationError as e:
                code = -1
                errors.append("Already read story: %s" % e)
            except MSocialSubscription.DoesNotExist:
                MSocialSubscription.mark_unsub_story_ids_as_read(
                    request.user.pk, social_user_id, story_ids, feed_id, request=request
                )
            except Feed.DoesNotExist:
                duplicate_feed = DuplicateFeed.objects.filter(duplicate_feed_id=feed_id)
                if duplicate_feed:
                    try:
                        socialsub = MSocialSubscription.objects.get(
                            user_id=request.user.pk, subscription_user_id=social_user_id
                        )
                        data = socialsub.mark_story_ids_as_read(
                            story_ids, duplicate_feed[0].feed.pk, request=request
                        )
                    except (UserSubscription.DoesNotExist, Feed.DoesNotExist):
                        code = -1
                        errors.append("No feed exists for feed_id %d." % feed_id)
                else:
                    continue
            r.publish(request.user.username, "feed:%s" % feed_id)
        r.publish(request.user.username, "social:%s" % social_user_id)

    data.update(code=code, errors=errors)
    return data


@required_params("story_id", feed_id=int)
@ajax_login_required
@json.json_view
def mark_story_as_unread(request):
    story_id = request.POST.get("story_id", None)
    feed_id = int(request.POST.get("feed_id", 0))

    try:
        usersub = UserSubscription.objects.select_related("feed").get(user=request.user, feed=feed_id)
        feed = usersub.feed
    except UserSubscription.DoesNotExist:
        usersub = None
        feed = Feed.get_by_id(feed_id)

    if usersub and not usersub.needs_unread_recalc:
        usersub.needs_unread_recalc = True
        usersub.save(update_fields=["needs_unread_recalc"])

    data = dict(code=0, payload=dict(story_id=story_id))

    story, found_original = MStory.find_story(feed_id, story_id)

    if not story:
        logging.user(request, "~FY~SBUnread~SN story in feed: %s (NOT FOUND)" % (feed))
        return dict(code=-1, message="Story not found.")

    message = RUserStory.story_can_be_marked_unread_by_user(story, request.user)
    if message:
        data["code"] = -1
        data["message"] = message
        return data

    if usersub:
        data = usersub.invert_read_stories_after_unread_story(story, request)

    social_subs = MSocialSubscription.mark_dirty_sharing_story(
        user_id=request.user.pk, story_feed_id=feed_id, story_guid_hash=story.guid_hash
    )
    dirty_count = social_subs and social_subs.count()
    dirty_count = ("(%s social_subs)" % dirty_count) if dirty_count else ""
    RUserStory.mark_story_hash_unread(request.user, story_hash=story.story_hash)

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, "feed:%s" % feed_id)

    logging.user(request, "~FY~SBUnread~SN story in feed: %s %s" % (feed, dirty_count))

    return data


@ajax_login_required
@json.json_view
@required_params("story_hash")
def mark_story_hash_as_unread(request):
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    story_hashes = request.POST.getlist("story_hash") or request.POST.getlist("story_hash[]")
    is_list = len(story_hashes) > 1
    datas = []
    for story_hash in story_hashes:
        feed_id, _ = MStory.split_story_hash(story_hash)
        story, _ = MStory.find_story(feed_id, story_hash)
        if not story:
            data = dict(
                code=-1,
                message="That story has been removed from the feed, no need to mark it unread.",
                story_hash=story_hash,
            )
            if not is_list:
                return data
            else:
                datas.append(data)
        message = RUserStory.story_can_be_marked_unread_by_user(story, request.user)
        if message:
            data = dict(code=-1, message=message, story_hash=story_hash)
            if not is_list:
                return data
            else:
                datas.append(data)

        # Also count on original subscription
        usersubs = UserSubscription.objects.filter(user=request.user.pk, feed=feed_id)
        if usersubs:
            usersub = usersubs[0]
            if not usersub.needs_unread_recalc:
                usersub.needs_unread_recalc = True
                usersub.save(update_fields=["needs_unread_recalc"])
            data = usersub.invert_read_stories_after_unread_story(story, request)
            r.publish(request.user.username, "feed:%s" % feed_id)

        feed_id, friend_ids = RUserStory.mark_story_hash_unread(request.user, story_hash)

        if friend_ids:
            socialsubs = MSocialSubscription.objects.filter(
                user_id=request.user.pk, subscription_user_id__in=friend_ids
            )
            for socialsub in socialsubs:
                if not socialsub.needs_unread_recalc:
                    socialsub.needs_unread_recalc = True
                    socialsub.save()
                r.publish(request.user.username, "social:%s" % socialsub.subscription_user_id)

        logging.user(request, "~FYUnread story in feed/socialsubs: %s/%s" % (feed_id, friend_ids))

        data = dict(code=1, story_hash=story_hash, feed_id=feed_id, friend_user_ids=friend_ids)
        if not is_list:
            return data
        else:
            datas.append(data)

    return datas


@ajax_login_required
@json.json_view
def mark_feed_as_read(request):
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    feed_ids = request.POST.getlist("feed_id") or request.POST.getlist("feed_id[]")
    cutoff_timestamp = int(request.POST.get("cutoff_timestamp", 0))
    direction = request.POST.get("direction", "older")
    infrequent = is_true(request.POST.get("infrequent", False))
    if infrequent:
        infrequent = request.POST.get("infrequent")
    multiple = len(feed_ids) > 1
    code = 1
    errors = []
    cutoff_date = datetime.datetime.fromtimestamp(cutoff_timestamp) if cutoff_timestamp else None

    if infrequent:
        feed_ids = Feed.low_volume_feeds(feed_ids, stories_per_month=infrequent)
        feed_ids = [str(f) for f in feed_ids]  # This method expects strings

    if cutoff_date:
        logging.user(
            request,
            "~FMMark %s feeds read, %s - cutoff: %s/%s"
            % (len(feed_ids), direction, cutoff_timestamp, cutoff_date),
        )

    for feed_id in feed_ids:
        if "social:" in feed_id:
            user_id = int(feed_id.replace("social:", ""))
            try:
                sub = MSocialSubscription.objects.get(user_id=request.user.pk, subscription_user_id=user_id)
            except MSocialSubscription.DoesNotExist:
                logging.user(request, "~FRCouldn't find socialsub: %s" % user_id)
                continue
            if not multiple:
                sub_user = User.objects.get(pk=sub.subscription_user_id)
                logging.user(request, "~FMMarking social feed as read: ~SB%s" % (sub_user.username,))
        else:
            try:
                feed = Feed.objects.get(id=feed_id)
                sub = UserSubscription.objects.get(feed=feed, user=request.user)
                if not multiple:
                    logging.user(request, "~FMMarking feed as read: ~SB%s" % (feed,))
            except (Feed.DoesNotExist, UserSubscription.DoesNotExist) as e:
                errors.append("User not subscribed: %s" % e)
                continue
            except ValueError as e:
                errors.append("Invalid feed_id: %s" % e)
                continue

        if not sub:
            errors.append("User not subscribed: %s" % feed_id)
            continue

        try:
            if direction == "older":
                marked_read = sub.mark_feed_read(cutoff_date=cutoff_date)
            else:
                marked_read = sub.mark_newer_stories_read(cutoff_date=cutoff_date)
            if marked_read and not multiple:
                r.publish(request.user.username, "feed:%s" % feed_id)
        except IntegrityError as e:
            errors.append("Could not mark feed as read: %s" % e)
            code = -1

    if multiple:
        logging.user(request, "~FMMarking ~SB%s~SN feeds as read" % len(feed_ids))
        r.publish(request.user.username, "refresh:%s" % ",".join(feed_ids))

    if errors:
        logging.user(request, "~FMMarking read had errors: ~FR%s" % errors)

    return dict(code=code, errors=errors, cutoff_date=cutoff_date, direction=direction)


def _parse_user_info(user):
    return {
        "user_info": {
            "is_anonymous": json.encode(user.is_anonymous),
            "is_authenticated": json.encode(user.is_authenticated),
            "username": json.encode(user.username if user.is_authenticated else "Anonymous"),
        }
    }


@ajax_login_required
@json.json_view
def add_url(request):
    code = 0
    url = request.POST["url"]
    folder = request.POST.get("folder", "").replace("river:", "")
    new_folder = request.POST.get("new_folder", "").replace("river:", "")
    auto_active = is_true(request.POST.get("auto_active", 1))
    skip_fetch = is_true(request.POST.get("skip_fetch", False))
    feed = None

    if not url:
        code = -1
        message = "Enter in the website address or the feed URL."
    elif any([(banned_url in url) for banned_url in BANNED_URLS]):
        code = -1
        message = "The publisher of this website has banned NewsBlur."
    elif re.match("(https?://)?twitter.com/\w+/?$", url):
        if not request.user.profile.is_premium:
            message = "You must be a premium subscriber to add Twitter feeds."
            code = -1
        else:
            # Check if Twitter API is active for user
            ss = MSocialServices.get_user(request.user.pk)
            try:
                if not ss.twitter_uid:
                    raise tweepy.TweepError("No API token")
                ss.twitter_api().me()
            except tweepy.TweepError:
                code = -1
                message = "Your Twitter connection isn't setup. Go to Manage - Friends/Followers and reconnect Twitter."

    if code == -1:
        return dict(code=code, message=message)

    if new_folder:
        usf, _ = UserSubscriptionFolders.objects.get_or_create(user=request.user)
        usf.add_folder(folder, new_folder)
        folder = new_folder

    code, message, us = UserSubscription.add_subscription(
        user=request.user, feed_address=url, folder=folder, auto_active=auto_active, skip_fetch=skip_fetch
    )
    feed = us and us.feed
    if feed:
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        r.publish(request.user.username, "reload:%s" % feed.pk)
        MUserSearch.schedule_index_feeds_for_search(feed.pk, request.user.pk)

    return dict(code=code, message=message, feed=feed)


@ajax_login_required
@json.json_view
def add_folder(request):
    folder = request.POST["folder"].replace("river:", "")
    parent_folder = request.POST.get("parent_folder", "").replace("river:", "")
    folders = None
    logging.user(request, "~FRAdding Folder: ~SB%s (in %s)" % (folder, parent_folder))

    if folder:
        code = 1
        message = ""
        user_sub_folders_object, _ = UserSubscriptionFolders.objects.get_or_create(user=request.user)
        user_sub_folders_object.add_folder(parent_folder, folder)
        folders = json.decode(user_sub_folders_object.folders)
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        r.publish(request.user.username, "reload:feeds")
    else:
        code = -1
        message = "Gotta write in a folder name."

    return dict(code=code, message=message, folders=folders)


@ajax_login_required
@json.json_view
def delete_feed(request):
    feed_id = int(request.POST["feed_id"])
    in_folder = request.POST.get("in_folder", "").replace("river:", "")
    if not in_folder or in_folder == " ":
        in_folder = ""

    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders.delete_feed(feed_id, in_folder)

    feed = Feed.objects.filter(pk=feed_id)
    if feed:
        feed[0].count_subscribers()

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, "reload:feeds")

    return dict(code=1, message="Removed %s from '%s'." % (feed, in_folder))


@ajax_login_required
@json.json_view
def delete_feed_by_url(request):
    message = ""
    code = 0
    url = request.POST["url"]
    in_folder = request.POST.get("in_folder", "").replace("river:", "")
    if in_folder == " ":
        in_folder = ""

    logging.user(request.user, "~FBFinding feed (delete_feed_by_url): %s" % url)
    feed = Feed.get_feed_from_url(url, create=False)
    if feed:
        user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
        user_sub_folders.delete_feed(feed.pk, in_folder)
        code = 1
        feed = Feed.objects.filter(pk=feed.pk)
        if feed:
            feed[0].count_subscribers()
    else:
        code = -1
        message = "URL not found."

    return dict(code=code, message=message)


@ajax_login_required
@json.json_view
def delete_folder(request):
    folder_to_delete = request.POST.get("folder_name") or request.POST.get("folder_to_delete")
    in_folder = request.POST.get("in_folder", None)
    feed_ids_in_folder = request.POST.getlist("feed_id") or request.POST.getlist("feed_id[]")
    feed_ids_in_folder = [int(f) for f in feed_ids_in_folder if f]

    request.user.profile.send_opml_export_email(
        reason="You have deleted an entire folder of feeds, so here's a backup of all of your subscriptions just in case."
    )

    # Works piss poor with duplicate folder titles, if they are both in the same folder.
    # Deletes all, but only in the same folder parent. But nobody should be doing that, right?
    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders.delete_folder(folder_to_delete, in_folder, feed_ids_in_folder)
    folders = json.decode(user_sub_folders.folders)

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, "reload:feeds")

    return dict(code=1, folders=folders)


@required_params("feeds_by_folder")
@ajax_login_required
@json.json_view
def delete_feeds_by_folder(request):
    feeds_by_folder = json.decode(request.POST["feeds_by_folder"])

    request.user.profile.send_opml_export_email(
        reason="You have deleted a number of feeds at once, so here's a backup of all of your subscriptions just in case."
    )

    # Works piss poor with duplicate folder titles, if they are both in the same folder.
    # Deletes all, but only in the same folder parent. But nobody should be doing that, right?
    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders.delete_feeds_by_folder(feeds_by_folder)
    folders = json.decode(user_sub_folders.folders)

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, "reload:feeds")

    return dict(code=1, folders=folders)


@ajax_login_required
@json.json_view
def rename_feed(request):
    feed = get_object_or_404(Feed, pk=int(request.POST["feed_id"]))
    try:
        user_sub = UserSubscription.objects.get(user=request.user, feed=feed)
    except UserSubscription.DoesNotExist:
        return dict(code=-1, message=f"You are not subscribed to {feed.feed_title}")

    feed_title = request.POST["feed_title"]

    logging.user(request, "~FRRenaming feed '~SB%s~SN' to: ~SB%s" % (feed.feed_title, feed_title))

    user_sub.user_title = feed_title
    user_sub.save()

    return dict(code=1)


@ajax_login_required
@json.json_view
def rename_folder(request):
    folder_to_rename = request.POST.get("folder_name") or request.POST.get("folder_to_rename")
    new_folder_name = request.POST["new_folder_name"]
    in_folder = request.POST.get("in_folder", "").replace("river:", "")
    if "Top Level" in in_folder:
        in_folder = ""
    code = 0

    # Works piss poor with duplicate folder titles, if they are both in the same folder.
    # renames all, but only in the same folder parent. But nobody should be doing that, right?
    if folder_to_rename and new_folder_name:
        user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
        user_sub_folders.rename_folder(folder_to_rename, new_folder_name, in_folder)
        code = 1
    else:
        code = -1

    return dict(code=code)


@ajax_login_required
@json.json_view
def move_feed_to_folders(request):
    feed_id = int(request.POST["feed_id"])
    in_folders = request.POST.getlist("in_folders", "") or request.POST.getlist("in_folders[]", "")
    to_folders = request.POST.getlist("to_folders", "") or request.POST.getlist("to_folders[]", "")

    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders = user_sub_folders.move_feed_to_folders(
        feed_id, in_folders=in_folders, to_folders=to_folders
    )

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, "reload:feeds")

    return dict(code=1, folders=json.decode(user_sub_folders.folders))


@ajax_login_required
@json.json_view
def move_feed_to_folder(request):
    feed_id = int(request.POST["feed_id"])
    in_folder = request.POST.get("in_folder", "")
    to_folder = request.POST.get("to_folder", "")

    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders = user_sub_folders.move_feed_to_folder(feed_id, in_folder=in_folder, to_folder=to_folder)

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, "reload:feeds")

    return dict(code=1, folders=json.decode(user_sub_folders.folders))


@ajax_login_required
@json.json_view
def move_folder_to_folder(request):
    folder_name = request.POST["folder_name"]
    in_folder = request.POST.get("in_folder", "")
    to_folder = request.POST.get("to_folder", "")

    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders = user_sub_folders.move_folder_to_folder(
        folder_name, in_folder=in_folder, to_folder=to_folder
    )

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, "reload:feeds")

    return dict(code=1, folders=json.decode(user_sub_folders.folders))


@required_params("feeds_by_folder", "to_folder")
@ajax_login_required
@json.json_view
def move_feeds_by_folder_to_folder(request):
    feeds_by_folder = json.decode(request.POST["feeds_by_folder"])
    to_folder = request.POST["to_folder"]
    new_folder = request.POST.get("new_folder", None)

    request.user.profile.send_opml_export_email(
        reason="You have moved a number of feeds at once, so here's a backup of all of your subscriptions just in case."
    )

    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)

    if new_folder:
        user_sub_folders.add_folder(to_folder, new_folder)
        to_folder = new_folder

    user_sub_folders = user_sub_folders.move_feeds_by_folder_to_folder(feeds_by_folder, to_folder)

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, "reload:feeds")

    return dict(code=1, folders=json.decode(user_sub_folders.folders))


@login_required
def add_feature(request):
    if not request.user.is_staff:
        return HttpResponseForbidden()

    code = -1
    form = FeatureForm(request.POST)

    if form.is_valid():
        form.save()
        code = 1
        return HttpResponseRedirect(reverse("index"))

    return dict(code=code)


@json.json_view
def load_features(request):
    user = get_user(request)
    page = max(int(request.GET.get("page", 0)), 0)
    if page > 1:
        logging.user(request, "~FBBrowse features: ~SBPage #%s" % (page + 1))
    features = list(Feature.objects.all()[page * 3 : (page + 1) * 3 + 1].values())
    features = [
        {
            "description": f["description"],
            "date": localtime_for_timezone(f["date"], user.profile.timezone).strftime("%b %d, %Y"),
        }
        for f in features
    ]
    return features


@ajax_login_required
@json.json_view
def save_feed_order(request):
    folders = request.POST.get("folders")
    if folders:
        # Test that folders can be JSON decoded
        folders_list = json.decode(folders)
        assert folders_list is not None
        logging.user(request, "~FBFeed re-ordering: ~SB%s folders/feeds" % (len(folders_list)))
        user_sub_folders = UserSubscriptionFolders.objects.get(user=request.user)
        user_sub_folders.folders = folders
        user_sub_folders.save()

    return {}


@json.json_view
def feeds_trainer(request):
    classifiers = []
    feed_id = request.GET.get("feed_id")
    user = get_user(request)
    usersubs = UserSubscription.objects.filter(user=user, active=True)

    if feed_id:
        feed = get_object_or_404(Feed, pk=feed_id)
        usersubs = usersubs.filter(feed=feed)
    usersubs = usersubs.select_related("feed").order_by("-feed__stories_last_month")

    for us in usersubs:
        if (not us.is_trained and us.feed.stories_last_month > 0) or feed_id:
            classifier = dict()
            classifier["classifiers"] = get_classifiers_for_user(user, feed_id=us.feed.pk)
            classifier["feed_id"] = us.feed_id
            classifier["stories_last_month"] = us.feed.stories_last_month
            classifier["num_subscribers"] = us.feed.num_subscribers
            classifier["feed_tags"] = (
                json.decode(us.feed.data.popular_tags) if us.feed.data.popular_tags else []
            )
            classifier["feed_authors"] = (
                json.decode(us.feed.data.popular_authors) if us.feed.data.popular_authors else []
            )
            classifiers.append(classifier)

    user.profile.has_trained_intelligence = True
    user.profile.save()

    logging.user(user, "~FGLoading Trainer: ~SB%s feeds" % (len(classifiers)))

    return classifiers


@ajax_login_required
@json.json_view
def save_feed_chooser(request):
    is_premium = request.user.profile.is_premium
    approved_feeds = request.POST.getlist("approved_feeds") or request.POST.getlist("approved_feeds[]")
    approved_feeds = [int(feed_id) for feed_id in approved_feeds if feed_id]
    approve_all = False
    if not is_premium:
        approved_feeds = approved_feeds[:64]
    elif is_premium and not approved_feeds:
        approve_all = True
    activated = 0
    usersubs = UserSubscription.objects.filter(user=request.user)

    for sub in usersubs:
        try:
            if sub.feed_id in approved_feeds or approve_all:
                activated += 1
                if not sub.active:
                    sub.active = True
                    sub.save()
                    if sub.feed.active_subscribers <= 0:
                        sub.feed.count_subscribers()
            elif sub.active:
                sub.active = False
                sub.save()
        except Feed.DoesNotExist:
            pass

    UserSubscription.queue_new_feeds(request.user)
    UserSubscription.refresh_stale_feeds(request.user, exclude_new=True)

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, "reload:feeds")

    logging.user(request, "~BB~FW~SBFeed chooser: ~FC%s~SN/~SB%s" % (activated, usersubs.count()))

    return {"activated": activated}


@ajax_login_required
def retrain_all_sites(request):
    for sub in UserSubscription.objects.filter(user=request.user):
        sub.is_trained = False
        sub.save()

    return feeds_trainer(request)


@login_required
def activate_premium_account(request):
    try:
        usersubs = UserSubscription.objects.select_related("feed").filter(user=request.user)
        for sub in usersubs:
            sub.active = True
            sub.save()
            if sub.feed.premium_subscribers <= 0:
                sub.feed.count_subscribers()
                sub.feed.schedule_feed_fetch_immediately()
    except Exception as e:
        logging.user(request, "~BR~FWPremium activation failed: {e} {usersubs}")

    request.user.profile.is_premium = True
    request.user.profile.save()

    return HttpResponseRedirect(reverse("index"))


@login_required
def login_as(request):
    if not request.user.is_staff:
        logging.user(request, "~SKNON-STAFF LOGGING IN AS ANOTHER USER!")
        assert False
        return HttpResponseForbidden()
    username = request.GET["user"]
    user = get_object_or_404(User, username__iexact=username)
    user.backend = settings.AUTHENTICATION_BACKENDS[0]
    login_user(request, user, backend="django.contrib.auth.backends.ModelBackend")
    return HttpResponseRedirect(reverse("index"))


def iframe_buster(request):
    logging.user(request, "~FB~SBiFrame bust!")
    return HttpResponse(status=204)


@required_params("story_id", feed_id=int)
@ajax_login_required
@json.json_view
def mark_story_as_starred(request):
    return _mark_story_as_starred(request)


@required_params("story_hash")
@ajax_login_required
@json.json_view
def mark_story_hash_as_starred(request):
    return _mark_story_as_starred(request)


def _mark_story_as_starred(request):
    code = 1
    feed_id = int(request.POST.get("feed_id", 0))
    story_id = request.POST.get("story_id", None)
    user_tags = request.POST.getlist("user_tags") or request.POST.getlist("user_tags[]")
    user_notes = request.POST.get("user_notes", None)
    highlights = request.POST.getlist("highlights") or request.POST.getlist("highlights[]") or []
    message = ""
    story_hashes = request.POST.getlist("story_hash") or request.POST.getlist("story_hash[]")
    is_list = len(story_hashes) > 1
    datas = []
    if not len(story_hashes):
        story, _ = MStory.find_story(story_feed_id=feed_id, story_id=story_id)
        if story:
            story_hashes = [story.story_hash]

    if not len(story_hashes):
        return {"code": -1, "message": "Could not find story to save."}

    for story_hash in story_hashes:
        story, _ = MStory.find_story(story_hash=story_hash)
        if not story:
            logging.user(request, "~FCStarring ~FRfailed~FC: %s not found" % (story_hash))
            datas.append({"code": -1, "message": "Could not save story, not found", "story_hash": story_hash})
            continue

        feed_id = story and story.story_feed_id

        story_db = dict([(k, v) for k, v in list(story._data.items()) if k is not None and v is not None])
        # Pop all existing user-specific fields because we don't want to reuse them from the found story
        # in case MStory.find_story uses somebody else's saved/shared story (because the original is deleted)
        story_db.pop("user_id", None)
        story_db.pop("starred_date", None)
        story_db.pop("id", None)
        story_db.pop("user_tags", None)
        story_db.pop("highlights", None)
        story_db.pop("user_notes", None)

        now = datetime.datetime.now()
        story_values = dict(
            starred_date=now, user_tags=user_tags, highlights=highlights, user_notes=user_notes, **story_db
        )
        params = dict(story_guid=story.story_guid, user_id=request.user.pk)
        starred_story = MStarredStory.objects(**params).limit(1)
        created = False
        changed_user_notes = False
        removed_user_tags = []
        removed_highlights = []
        if not starred_story:
            params.update(story_values)
            if "story_latest_content_z" in params:
                params.pop("story_latest_content_z")
            try:
                starred_story = MStarredStory.objects.create(**params)
            except OperationError as e:
                logging.user(
                    request, "~FCStarring ~FRfailed~FC: ~SB%s (~FM~SB%s~FC~SN)" % (story.story_title[:32], e)
                )
                datas.append(
                    {"code": -1, "message": "Could not save story due to: %s" % e, "story_hash": story_hash}
                )

            created = True
            MActivity.new_starred_story(
                user_id=request.user.pk,
                story_title=story.story_title,
                story_feed_id=feed_id,
                story_id=starred_story.story_guid,
            )
            new_user_tags = user_tags
            new_highlights = highlights
            changed_user_notes = bool(user_notes)
            MStarredStoryCounts.adjust_count(request.user.pk, feed_id=feed_id, amount=1)
        else:
            starred_story = starred_story[0]
            new_user_tags = list(set(user_tags) - set(starred_story.user_tags or []))
            removed_user_tags = list(set(starred_story.user_tags or []) - set(user_tags))
            new_highlights = list(set(highlights) - set(starred_story.highlights or []))
            removed_highlights = list(set(starred_story.highlights or []) - set(highlights))
            changed_user_notes = bool(user_notes != starred_story.user_notes)
            starred_story.user_tags = user_tags
            starred_story.highlights = highlights
            starred_story.user_notes = user_notes
            starred_story.save()

        if len(highlights) == 1 and len(new_highlights) == 1:
            MStarredStoryCounts.adjust_count(request.user.pk, highlights=True, amount=1)
        elif len(highlights) == 0 and len(removed_highlights):
            MStarredStoryCounts.adjust_count(request.user.pk, highlights=True, amount=-1)

        for tag in new_user_tags:
            MStarredStoryCounts.adjust_count(request.user.pk, tag=tag, amount=1)
        for tag in removed_user_tags:
            MStarredStoryCounts.adjust_count(request.user.pk, tag=tag, amount=-1)

        if random.random() < 0.01:
            MStarredStoryCounts.schedule_count_tags_for_user(request.user.pk)
        MStarredStoryCounts.count_for_user(request.user.pk, total_only=True)
        starred_counts, starred_count = MStarredStoryCounts.user_counts(request.user.pk, include_total=True)
        if not starred_count and len(starred_counts):
            starred_count = MStarredStory.objects(user_id=request.user.pk).count()

        if not changed_user_notes:
            r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
            r.publish(request.user.username, "story:starred:%s" % story.story_hash)

        if created:
            logging.user(
                request,
                "~FCStarring: ~SB%s (~FM~SB%s~FC~SN)" % (story.story_title[:32], starred_story.user_tags),
            )
        else:
            logging.user(
                request,
                "~FCUpdating starred:~SN~FC ~SB%s~SN (~FM~SB%s~FC~SN/~FM%s~FC)"
                % (story.story_title[:32], starred_story.user_tags, starred_story.user_notes),
            )

        datas.append(
            {
                "code": code,
                "message": message,
                "starred_count": starred_count,
                "starred_counts": starred_counts,
            }
        )

    if len(datas) >= 2:
        return datas
    elif len(datas) == 1:
        return datas[0]
    return datas


@required_params("story_id")
@ajax_login_required
@json.json_view
def mark_story_as_unstarred(request):
    return _mark_story_as_unstarred(request)


@required_params("story_hash")
@ajax_login_required
@json.json_view
def mark_story_hash_as_unstarred(request):
    return _mark_story_as_unstarred(request)


def _mark_story_as_unstarred(request):
    code = 1
    story_id = request.POST.get("story_id", None)
    story_hashes = request.POST.getlist("story_hash") or request.POST.getlist("story_hash[]")
    starred_counts = None
    starred_story = None
    if story_id:
        starred_story = MStarredStory.objects(user_id=request.user.pk, story_guid=story_id)
        if starred_story:
            starred_story = starred_story[0]
            story_hashes = [starred_story.story_hash]
        else:
            story_hashes = [story_id]

    datas = []
    for story_hash in story_hashes:
        starred_story = MStarredStory.objects(user_id=request.user.pk, story_hash=story_hash)
        if not starred_story:
            logging.user(request, "~FCUnstarring ~FRfailed~FC: %s not found" % (story_hash))
            datas.append(
                {"code": -1, "message": "Could not unsave story, not found", "story_hash": story_hash}
            )
            continue

        starred_story = starred_story[0]
        logging.user(request, "~FCUnstarring: ~SB%s" % (starred_story.story_title[:50]))
        user_tags = starred_story.user_tags
        feed_id = starred_story.story_feed_id
        MActivity.remove_starred_story(
            user_id=request.user.pk,
            story_feed_id=starred_story.story_feed_id,
            story_id=starred_story.story_guid,
        )
        starred_story.user_id = 0
        try:
            starred_story.save()
        except NotUniqueError:
            starred_story.delete()

        MStarredStoryCounts.adjust_count(request.user.pk, feed_id=feed_id, amount=-1)

        for tag in user_tags:
            try:
                MStarredStoryCounts.adjust_count(request.user.pk, tag=tag, amount=-1)
            except MStarredStoryCounts.DoesNotExist:
                pass
        MStarredStoryCounts.schedule_count_tags_for_user(request.user.pk)
        MStarredStoryCounts.count_for_user(request.user.pk, total_only=True)
        starred_counts = MStarredStoryCounts.user_counts(request.user.pk)

        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        r.publish(request.user.username, "story:unstarred:%s" % starred_story.story_hash)

    if not story_hashes:
        datas.append(dict(code=-1, message=f"Failed to find {story_hashes}"))

    return {"code": code, "starred_counts": starred_counts, "messages": datas}


@ajax_login_required
@json.json_view
def starred_counts(request):
    starred_counts, starred_count = MStarredStoryCounts.user_counts(request.user.pk, include_total=True)
    logging.user(
        request,
        "~FCRequesting starred counts: ~SB%s stories (%s tags)"
        % (starred_count, len([s for s in starred_counts if s["tag"]])),
    )

    return {"starred_count": starred_count, "starred_counts": starred_counts}


@ajax_login_required
@json.json_view
def send_story_email(request):
    def validate_email_as_bool(email):
        try:
            validate_email(email)
            return True
        except:
            return False

    code = 1
    message = "OK"
    user = get_user(request)
    story_id = request.POST["story_id"]
    feed_id = request.POST["feed_id"]
    to_addresses = request.POST.get("to", "").replace(",", " ").replace("  ", " ").strip().split(" ")
    from_name = request.POST["from_name"]
    from_email = request.POST["from_email"]
    email_cc = is_true(request.POST.get("email_cc", "true"))
    comments = request.POST["comments"]
    comments = comments[:2048]  # Separated due to PyLint
    from_address = "share@newsblur.com"
    share_user_profile = MSocialProfile.get_user(request.user.pk)

    quota = 32 if user.profile.is_premium else 1
    if share_user_profile.over_story_email_quota(quota=quota):
        code = -1
        if user.profile.is_premium:
            message = "You can only send %s stories per day by email." % quota
        else:
            message = "Upgrade to a premium subscription to send more than one story per day by email."
        logging.user(
            request,
            "~BRNOT ~BMSharing story by email to %s recipient, over quota: %s/%s"
            % (len(to_addresses), story_id, feed_id),
        )
    elif not to_addresses:
        code = -1
        message = "Please provide at least one email address."
    elif not all(validate_email_as_bool(to_address) for to_address in to_addresses if to_addresses):
        code = -1
        message = "You need to send the email to a valid email address."
    elif not validate_email_as_bool(from_email):
        code = -1
        message = "You need to provide your email address."
    elif not from_name:
        code = -1
        message = "You need to provide your name."
    else:
        story, _ = MStory.find_story(feed_id, story_id)
        story = Feed.format_story(story, feed_id, text=True)
        feed = Feed.get_by_id(story["story_feed_id"])
        params = {
            "to_addresses": to_addresses,
            "from_name": from_name,
            "from_email": from_email,
            "email_cc": email_cc,
            "comments": comments,
            "from_address": from_address,
            "story": story,
            "feed": feed,
            "share_user_profile": share_user_profile,
        }
        text = render_to_string("mail/email_story.txt", params)
        html = render_to_string("mail/email_story.xhtml", params)
        subject = "%s" % (story["story_title"])
        cc = None
        if email_cc:
            cc = ["%s <%s>" % (from_name, from_email)]
        subject = subject.replace("\n", " ")
        msg = EmailMultiAlternatives(
            subject,
            text,
            from_email="NewsBlur <%s>" % from_address,
            to=to_addresses,
            cc=cc,
            headers={"Reply-To": "%s <%s>" % (from_name, from_email)},
        )
        msg.attach_alternative(html, "text/html")
        # try:
        msg.send()
        # except boto.ses.connection.BotoServerError as e:
        #     code = -1
        #     message = "Email error: %s" % str(e)

        share_user_profile.save_sent_email()

        logging.user(
            request,
            "~BMSharing story by email to %s recipient%s (%s): ~FY~SB%s~SN~BM~FY/~SB%s"
            % (
                len(to_addresses),
                "" if len(to_addresses) == 1 else "s",
                to_addresses,
                story["story_title"][:50],
                feed and feed.feed_title[:50],
            ),
        )

    return {"code": code, "message": message}


@json.json_view
def load_tutorial(request):
    if request.GET.get("finished"):
        logging.user(request, "~BY~FW~SBFinishing Tutorial")
        return {}
    else:
        newsblur_feed = Feed.objects.filter(feed_address__icontains="blog.newsblur.com").order_by("-pk")[0]
        logging.user(request, "~BY~FW~SBLoading Tutorial")
        return {"newsblur_feed": newsblur_feed.canonical()}


@required_params("query", "feed_id")
@json.json_view
def save_search(request):
    feed_id = request.POST["feed_id"]
    query = request.POST["query"]

    MSavedSearch.save_search(user_id=request.user.pk, feed_id=feed_id, query=query)

    saved_searches = MSavedSearch.user_searches(request.user.pk)

    return {
        "saved_searches": saved_searches,
    }


@required_params("query", "feed_id")
@json.json_view
def delete_search(request):
    feed_id = request.POST["feed_id"]
    query = request.POST["query"]

    MSavedSearch.delete_search(user_id=request.user.pk, feed_id=feed_id, query=query)

    saved_searches = MSavedSearch.user_searches(request.user.pk)

    return {
        "saved_searches": saved_searches,
    }


@required_params("river_id", "river_side", "river_order")
@json.json_view
def save_dashboard_river(request):
    river_id = request.POST["river_id"]
    river_side = request.POST["river_side"]
    river_order = int(request.POST["river_order"])

    logging.user(request, "~FCSaving dashboard river: ~SB%s~SN (%s %s)" % (river_id, river_side, river_order))

    MDashboardRiver.save_user(request.user.pk, river_id, river_side, river_order)
    dashboard_rivers = MDashboardRiver.get_user_rivers(request.user.pk)

    return {
        "dashboard_rivers": dashboard_rivers,
    }


@required_params("river_id", "river_side", "river_order")
@json.json_view
def remove_dashboard_river(request):
    river_id = request.POST["river_id"]
    river_side = request.POST["river_side"]
    river_order = int(request.POST["river_order"])

    logging.user(
        request, "~FRRemoving~FC dashboard river: ~SB%s~SN (%s %s)" % (river_id, river_side, river_order)
    )

    MDashboardRiver.remove_river(request.user.pk, river_side, river_order)
    dashboard_rivers = MDashboardRiver.get_user_rivers(request.user.pk)

    return {
        "dashboard_rivers": dashboard_rivers,
    }


def print_story(request):
    story_hash = request.GET["story_hash"]
    text_view = request.GET.get("text", False)
    timezone = request.user.profile.timezone
    try:
        story = MStory.objects.get(story_hash=story_hash)
    except MStory.DoesNotExist:
        raise Http404

    story_date = story.story_date

    if text_view:
        original_text = story.fetch_original_text(request=request)
        story = Feed.format_story(story, story.story_feed_id, text=text_view)
        story["story_content"] = original_text.decode("utf-8")
    else:
        story = Feed.format_story(story, story.story_feed_id)
    return render(
        request,
        "reader/print.xhtml",
        {"story": story, "local_datetime": localtime_for_timezone(story_date, timezone)},
    )


@json.json_view
def save_dashboard_rivers(request):
    try:
        data = json.decode(request.body)
        dashboard_rivers = data["dashboard_rivers"]
    except KeyError:
        return {"code": -1, "message": "Invalid JSON data"}

    if not isinstance(dashboard_rivers, list):
        return {"code": -1, "message": "dashboard_rivers must be a list"}

    # Validate all rivers first
    for river_data in dashboard_rivers:
        if not all(k in river_data for k in ["river_id", "river_side", "river_order"]):
            return {"code": -1, "message": "Each river must have river_id, river_side, and river_order"}

        try:
            river_order = int(river_data["river_order"])
            if river_order < 0:
                return {"code": -1, "message": "river_order must be non-negative"}
        except ValueError:
            return {"code": -1, "message": "river_order must be an integer"}

    logging.user(request, "~FCSaving dashboard rivers: ~SB%s~SN" % dashboard_rivers)

    # Delete all existing rivers for this user
    MDashboardRiver.objects(user_id=request.user.pk).delete()

    # Save new rivers in order
    for river_data in dashboard_rivers:
        MDashboardRiver.objects.create(
            user_id=request.user.pk,
            river_id=river_data["river_id"],
            river_side=river_data["river_side"],
            river_order=int(river_data["river_order"]),
        )

    # Get updated rivers
    dashboard_rivers = MDashboardRiver.get_user_rivers(request.user.pk)

    return {
        "dashboard_rivers": dashboard_rivers,
    }
