import datetime
import time
import boto
import redis
import requests
import random
import zlib
from django.shortcuts import get_object_or_404
from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.template.loader import render_to_string
from django.db import IntegrityError
from django.db.models import Q
from django.views.decorators.cache import never_cache
from django.core.urlresolvers import reverse
from django.contrib.auth import login as login_user
from django.contrib.auth import logout as logout_user
from django.contrib.auth.models import User
from django.http import HttpResponse, HttpResponseRedirect, HttpResponseForbidden, Http404
from django.conf import settings
from django.core.mail import mail_admins
from django.core.validators import email_re
from django.core.mail import EmailMultiAlternatives
from django.contrib.sites.models import Site
from django.utils import feedgenerator
from mongoengine.queryset import OperationError
from mongoengine.queryset import NotUniqueError
from apps.recommendations.models import RecommendedFeed
from apps.analyzer.models import MClassifierTitle, MClassifierAuthor, MClassifierFeed, MClassifierTag
from apps.analyzer.models import apply_classifier_titles, apply_classifier_feeds
from apps.analyzer.models import apply_classifier_authors, apply_classifier_tags
from apps.analyzer.models import get_classifiers_for_user, sort_classifiers_by_feed
from apps.profile.models import Profile
from apps.reader.models import UserSubscription, UserSubscriptionFolders, RUserStory, Feature
from apps.reader.forms import SignupForm, LoginForm, FeatureForm
from apps.rss_feeds.models import MFeedIcon, MStarredStoryCounts
from apps.search.models import MUserSearch
from apps.statistics.models import MStatistics
# from apps.search.models import SearchStarredStory
try:
    from apps.rss_feeds.models import Feed, MFeedPage, DuplicateFeed, MStory, MStarredStory
except:
    pass
from apps.social.models import MSharedStory, MSocialProfile, MSocialServices
from apps.social.models import MSocialSubscription, MActivity, MInteraction
from apps.categories.models import MCategory
from apps.social.views import load_social_page
from apps.rss_feeds.tasks import ScheduleImmediateFetches
from utils import json_functions as json
from utils.user_functions import get_user, ajax_login_required
from utils.feed_functions import relative_timesince
from utils.story_functions import format_story_link_date__short
from utils.story_functions import format_story_link_date__long
from utils.story_functions import strip_tags
from utils import log as logging
from utils.view_functions import get_argument_or_404, render_to, is_true
from utils.view_functions import required_params
from utils.ratelimit import ratelimit
from vendor.timezones.utilities import localtime_for_timezone


BANNED_URLS = [
    "brentozar.com",
]

@never_cache
@render_to('reader/dashboard.xhtml')
def index(request, **kwargs):
    if request.method == "GET" and request.subdomain and request.subdomain not in ['dev', 'www', 'debug']:
        username = request.subdomain
        try:
            if '.' in username:
                username = username.split('.')[0]
            user = User.objects.get(username__iexact=username)
        except User.DoesNotExist:
            return HttpResponseRedirect('http://%s%s' % (
                Site.objects.get_current().domain,
                reverse('index')))
        return load_social_page(request, user_id=user.pk, username=request.subdomain, **kwargs)

    if request.user.is_anonymous():
        return welcome(request, **kwargs)
    else:
        return dashboard(request, **kwargs)

def dashboard(request, **kwargs):
    user              = request.user
    feed_count        = UserSubscription.objects.filter(user=request.user).count()
    recommended_feeds = RecommendedFeed.objects.filter(is_public=True,
                                                       approved_date__lte=datetime.datetime.now()
                                                       ).select_related('feed')[:2]
    unmoderated_feeds = []
    if user.is_staff:
        unmoderated_feeds = RecommendedFeed.objects.filter(is_public=False,
                                                           declined_date__isnull=True
                                                           ).select_related('feed')[:2]
    statistics        = MStatistics.all()
    social_profile    = MSocialProfile.get_user(user.pk)

    start_import_from_google_reader = request.session.get('import_from_google_reader', False)
    if start_import_from_google_reader:
        del request.session['import_from_google_reader']
    
    if not user.is_active:
        url = "https://%s%s" % (Site.objects.get_current().domain,
                                 reverse('stripe-form'))
        return HttpResponseRedirect(url)

    logging.user(request, "~FBLoading dashboard")

    return {
        'user_profile'      : user.profile,
        'feed_count'        : feed_count,
        'account_images'    : range(1, 4),
        'recommended_feeds' : recommended_feeds,
        'unmoderated_feeds' : unmoderated_feeds,
        'statistics'        : statistics,
        'social_profile'    : social_profile,
        'start_import_from_google_reader': start_import_from_google_reader,
        'debug'             : settings.DEBUG,
    }, "reader/dashboard.xhtml"
    
def welcome(request, **kwargs):
    user              = get_user(request)
    statistics        = MStatistics.all()
    social_profile    = MSocialProfile.get_user(user.pk)
    
    if request.method == "POST":
        if request.POST.get('submit', '').startswith('log'):
            login_form  = LoginForm(request.POST, prefix='login')
            signup_form = SignupForm(prefix='signup')
        else:
            login_form  = LoginForm(prefix='login')
            signup_form = SignupForm(request.POST, prefix='signup')
    else:
        login_form  = LoginForm(prefix='login')
        signup_form = SignupForm(prefix='signup')
    
    logging.user(request, "~FBLoading welcome")
    
    return {
        'user_profile'      : hasattr(user, 'profile') and user.profile,
        'login_form'        : login_form,
        'signup_form'       : signup_form,
        'statistics'        : statistics,
        'social_profile'    : social_profile,
        'post_request'      : request.method == 'POST',
    }, "reader/welcome.xhtml"

@never_cache
def login(request):
    code = -1
    message = ""
    if request.method == "POST":
        form = LoginForm(request.POST, prefix='login')
        if form.is_valid():
            login_user(request, form.get_user())
            if request.POST.get('api'):
                logging.user(form.get_user(), "~FG~BB~SKiPhone Login~FW")
                code = 1
            else:
                logging.user(form.get_user(), "~FG~BBLogin~FW")
                return HttpResponseRedirect(reverse('index'))
        else:
            message = form.errors.items()[0][1][0]

    if request.POST.get('api'):
        return HttpResponse(json.encode(dict(code=code, message=message)), mimetype='application/json')
    else:
        return index(request)
    
@never_cache
def signup(request):
    if request.method == "POST":
        form = SignupForm(prefix='signup', data=request.POST)
        if form.is_valid():
            new_user = form.save()
            login_user(request, new_user)
            logging.user(new_user, "~FG~SB~BBNEW SIGNUP: ~FW%s" % new_user.email)
            if not new_user.is_active:
                url = "https://%s%s" % (Site.objects.get_current().domain,
                                         reverse('stripe-form'))
                return HttpResponseRedirect(url)
    
    return index(request)
        
@never_cache
def logout(request):
    logging.user(request, "~FG~BBLogout~FW")
    logout_user(request)
    
    if request.GET.get('api'):
        return HttpResponse(json.encode(dict(code=1)), mimetype='application/json')
    else:
        return HttpResponseRedirect(reverse('index'))

def autologin(request, username, secret):
    next = request.GET.get('next', '')
    
    if not username or not secret:
        return HttpResponseForbidden()
    
    profile = Profile.objects.filter(user__username=username, secret_token=secret)
    if not profile:
        return HttpResponseForbidden()

    user = profile[0].user
    user.backend = settings.AUTHENTICATION_BACKENDS[0]
    login_user(request, user)
    logging.user(user, "~FG~BB~SKAuto-Login. Next stop: %s~FW" % (next if next else 'Homepage',))
    
    if next and not next.startswith('/'):
        next = '?next=' + next
        return HttpResponseRedirect(reverse('index') + next)
    elif next:
        return HttpResponseRedirect(next)
    else:
        return HttpResponseRedirect(reverse('index'))
    
@ratelimit(minutes=1, requests=24)
@never_cache
@json.json_view
def load_feeds(request):
    user             = get_user(request)
    feeds            = {}
    include_favicons = request.REQUEST.get('include_favicons', False)
    flat             = request.REQUEST.get('flat', False)
    update_counts    = request.REQUEST.get('update_counts', False)
    version          = int(request.REQUEST.get('v', 1))
    
    if include_favicons == 'false': include_favicons = False
    if update_counts == 'false': update_counts = False
    if flat == 'false': flat = False
    
    if flat: return load_feeds_flat(request)
    
    try:
        folders = UserSubscriptionFolders.objects.get(user=user)
    except UserSubscriptionFolders.DoesNotExist:
        data = dict(feeds=[], folders=[])
        return data
    except UserSubscriptionFolders.MultipleObjectsReturned:
        UserSubscriptionFolders.objects.filter(user=user)[1:].delete()
        folders = UserSubscriptionFolders.objects.get(user=user)
    
    user_subs = UserSubscription.objects.select_related('feed').filter(user=user)
    
    day_ago = datetime.datetime.now() - datetime.timedelta(days=1)
    scheduled_feeds = []
    for sub in user_subs:
        pk = sub.feed_id
        if update_counts and sub.needs_unread_recalc:
            sub.calculate_feed_scores(silent=True)
        feeds[pk] = sub.canonical(include_favicon=include_favicons)
        
        if not sub.active: continue
        if not sub.feed.active and not sub.feed.has_feed_exception:
            scheduled_feeds.append(sub.feed.pk)
        elif sub.feed.active_subscribers <= 0:
            scheduled_feeds.append(sub.feed.pk)
        elif sub.feed.next_scheduled_update < day_ago:
            scheduled_feeds.append(sub.feed.pk)
    
    if len(scheduled_feeds) > 0 and request.user.is_authenticated():
        logging.user(request, "~SN~FMTasking the scheduling immediate fetch of ~SB%s~SN feeds..." % 
                     len(scheduled_feeds))
        ScheduleImmediateFetches.apply_async(kwargs=dict(feed_ids=scheduled_feeds, user_id=user.pk))

    starred_counts, starred_count = MStarredStoryCounts.user_counts(user.pk, include_total=True)
    if not starred_count and len(starred_counts):
        starred_count = MStarredStory.objects(user_id=user.pk).count()
    
    social_params = {
        'user_id': user.pk,
        'include_favicon': include_favicons,
        'update_counts': update_counts,
    }
    social_feeds = MSocialSubscription.feeds(**social_params)
    social_profile = MSocialProfile.profile(user.pk)
    social_services = MSocialServices.profile(user.pk)
    
    categories = None
    if not user_subs:
        categories = MCategory.serialize()

    logging.user(request, "~FB~SBLoading ~FY%s~FB/~FM%s~FB feeds/socials%s" % (
            len(feeds.keys()), len(social_feeds), '. ~FCUpdating counts.' if update_counts else ''))

    data = {
        'feeds': feeds.values() if version == 2 else feeds,
        'social_feeds': social_feeds,
        'social_profile': social_profile,
        'social_services': social_services,
        'user_profile': user.profile,
        "is_staff": user.is_staff,
        'folders': json.decode(folders.folders),
        'starred_count': starred_count,
        'starred_counts': starred_counts,
        'categories': categories
    }
    return data

@json.json_view
def load_feed_favicons(request):
    user = get_user(request)
    feed_ids = request.REQUEST.getlist('feed_ids')
    
    if not feed_ids:
        user_subs = UserSubscription.objects.select_related('feed').filter(user=user, active=True)
        feed_ids  = [sub['feed__pk'] for sub in user_subs.values('feed__pk')]

    feed_icons = dict([(i.feed_id, i.data) for i in MFeedIcon.objects(feed_id__in=feed_ids)])
        
    return feed_icons

def load_feeds_flat(request):
    user = request.user
    include_favicons = is_true(request.REQUEST.get('include_favicons', False))
    update_counts    = is_true(request.REQUEST.get('update_counts', True))
    
    feeds = {}
    day_ago = datetime.datetime.now() - datetime.timedelta(days=1)
    scheduled_feeds = []
    iphone_version = "2.1"
    
    if include_favicons == 'false': include_favicons = False
    if update_counts == 'false': update_counts = False
    
    if not user.is_authenticated():
        return HttpResponseForbidden()
    
    try:
        folders = UserSubscriptionFolders.objects.get(user=user)
    except UserSubscriptionFolders.DoesNotExist:
        folders = []
        
    user_subs = UserSubscription.objects.select_related('feed').filter(user=user, active=True)
    if not user_subs and folders:
        folders.auto_activate()
        user_subs = UserSubscription.objects.select_related('feed').filter(user=user, active=True)

    for sub in user_subs:
        if update_counts and sub.needs_unread_recalc:
            sub.calculate_feed_scores(silent=True)
        feeds[sub.feed_id] = sub.canonical(include_favicon=include_favicons)
        if not sub.feed.active and not sub.feed.has_feed_exception:
            scheduled_feeds.append(sub.feed.pk)
        elif sub.feed.active_subscribers <= 0:
            scheduled_feeds.append(sub.feed.pk)
        elif sub.feed.next_scheduled_update < day_ago:
            scheduled_feeds.append(sub.feed.pk)
    
    if len(scheduled_feeds) > 0 and request.user.is_authenticated():
        logging.user(request, "~SN~FMTasking the scheduling immediate fetch of ~SB%s~SN feeds..." % 
                     len(scheduled_feeds))
        ScheduleImmediateFetches.apply_async(kwargs=dict(feed_ids=scheduled_feeds, user_id=user.pk))
    
    flat_folders = []
    if folders:
        flat_folders = folders.flatten_folders(feeds=feeds)
        
    social_params = {
        'user_id': user.pk,
        'include_favicon': include_favicons,
        'update_counts': update_counts,
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
        
    logging.user(request, "~FB~SBLoading ~FY%s~FB/~FM%s~FB feeds/socials ~FMflat~FB%s" % (
            len(feeds.keys()), len(social_feeds), '. ~FCUpdating counts.' if update_counts else ''))

    data = {
        "flat_folders": flat_folders, 
        "feeds": feeds,
        "social_feeds": social_feeds,
        "social_profile": social_profile,
        "social_services": social_services,
        "user": user.username,
        "is_staff": user.is_staff,
        "user_profile": user.profile,
        "iphone_version": iphone_version,
        "categories": categories,
        'starred_count': starred_count,
        'starred_counts': starred_counts,
    }
    return data

@ratelimit(minutes=1, requests=10)
@never_cache
@json.json_view
def refresh_feeds(request):
    user = get_user(request)
    feed_ids = request.REQUEST.getlist('feed_id')
    check_fetch_status = request.REQUEST.get('check_fetch_status')
    favicons_fetching = request.REQUEST.getlist('favicons_fetching')
    social_feed_ids = [feed_id for feed_id in feed_ids if 'social:' in feed_id]
    feed_ids = list(set(feed_ids) - set(social_feed_ids))
    
    feeds = {}
    if feed_ids or (not social_feed_ids and not feed_ids):
        feeds = UserSubscription.feeds_with_updated_counts(user, feed_ids=feed_ids, 
                                                           check_fetch_status=check_fetch_status)
    social_feeds = {}
    if social_feed_ids or (not social_feed_ids and not feed_ids):
        social_feeds = MSocialSubscription.feeds_with_updated_counts(user, social_feed_ids=social_feed_ids)
    
    favicons_fetching = [int(f) for f in favicons_fetching if f]
    feed_icons = {}
    if favicons_fetching:
        feed_icons = dict([(i.feed_id, i) for i in MFeedIcon.objects(feed_id__in=favicons_fetching)])
    
    for feed_id, feed in feeds.items():
        if feed_id in favicons_fetching and feed_id in feed_icons:
            feeds[feed_id]['favicon'] = feed_icons[feed_id].data
            feeds[feed_id]['favicon_color'] = feed_icons[feed_id].color
            feeds[feed_id]['favicon_fetching'] = feed.get('favicon_fetching')

    user_subs = UserSubscription.objects.filter(user=user, active=True).only('feed')
    sub_feed_ids = [s.feed_id for s in user_subs]

    if favicons_fetching:
        moved_feed_ids = [f for f in favicons_fetching if f not in sub_feed_ids]
        for moved_feed_id in moved_feed_ids:
            duplicate_feeds = DuplicateFeed.objects.filter(duplicate_feed_id=moved_feed_id)

            if duplicate_feeds and duplicate_feeds[0].feed.pk in feeds:
                feeds[moved_feed_id] = feeds[duplicate_feeds[0].feed_id]
                feeds[moved_feed_id]['dupe_feed_id'] = duplicate_feeds[0].feed_id
    
    if check_fetch_status:
        missing_feed_ids = list(set(feed_ids) - set(sub_feed_ids))
        if missing_feed_ids:
            duplicate_feeds = DuplicateFeed.objects.filter(duplicate_feed_id__in=missing_feed_ids)
            for duplicate_feed in duplicate_feeds:
                feeds[duplicate_feed.duplicate_feed_id] = {'id': duplicate_feed.feed_id}
    
    interactions_count = MInteraction.user_unread_count(user.pk)

    if True or settings.DEBUG or check_fetch_status:
        logging.user(request, "~FBRefreshing %s feeds (%s/%s)" % (
            len(feeds.keys()), check_fetch_status, len(favicons_fetching)))

    return {
        'feeds': feeds, 
        'social_feeds': social_feeds,
        'interactions_count': interactions_count,
    }

@json.json_view
def interactions_count(request):
    user = get_user(request)

    interactions_count = MInteraction.user_unread_count(user.pk)

    return {
        'interactions_count': interactions_count,
    }
    
@never_cache
@ajax_login_required
@json.json_view
def feed_unread_count(request):
    user = request.user
    feed_ids = request.REQUEST.getlist('feed_id')
    force = request.REQUEST.get('force', False)
    social_feed_ids = [feed_id for feed_id in feed_ids if 'social:' in feed_id]
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
        feed_title = MSocialProfile.objects.get(user_id=social_feed_ids[0].replace('social:', '')).username
    else:
        feed_title = "%s feeds" % (len(feeds) + len(social_feeds))
    logging.user(request, "~FBUpdating unread count on: %s" % feed_title)
    
    return {'feeds': feeds, 'social_feeds': social_feeds}
    
def refresh_feed(request, feed_id):
    user = get_user(request)
    feed = get_object_or_404(Feed, pk=feed_id)
    
    feed = feed.update(force=True, compute_scores=False)
    usersub = UserSubscription.objects.get(user=user, feed=feed)
    usersub.calculate_feed_scores(silent=False)
    
    logging.user(request, "~FBRefreshing feed: %s" % feed)
    
    return load_single_feed(request, feed_id)
    
@never_cache
@json.json_view
def load_single_feed(request, feed_id):
    start                   = time.time()
    user                    = get_user(request)
    # offset                  = int(request.REQUEST.get('offset', 0))
    # limit                   = int(request.REQUEST.get('limit', 6))
    limit                   = 6
    page                    = int(request.REQUEST.get('page', 1))
    offset                  = limit * (page-1)
    order                   = request.REQUEST.get('order', 'newest')
    read_filter             = request.REQUEST.get('read_filter', 'all')
    query                   = request.REQUEST.get('query')
    include_story_content   = is_true(request.REQUEST.get('include_story_content', True))
    include_hidden          = is_true(request.REQUEST.get('include_hidden', False))
    message                 = None
    user_search             = None

    dupe_feed_id = None
    user_profiles = []
    now = localtime_for_timezone(datetime.datetime.now(), user.profile.timezone)
    if not feed_id: raise Http404

    feed_address = request.REQUEST.get('feed_address')
    feed = Feed.get_by_id(feed_id, feed_address=feed_address)
    if not feed:
        raise Http404
    
    try:
        usersub = UserSubscription.objects.get(user=user, feed=feed)
    except UserSubscription.DoesNotExist:
        usersub = None
    
    if query:
        if user.profile.is_premium:
            user_search = MUserSearch.get_user(user.pk)
            user_search.touch_search_date()
            stories = feed.find_stories(query, order=order, offset=offset, limit=limit)
        else:
            stories = []
            message = "You must be a premium subscriber to search."
    elif read_filter == 'starred':
        mstories = MStarredStory.objects(
            user_id=user.pk,
            story_feed_id=feed_id
        ).order_by('%sstarred_date' % ('-' if order == 'newest' else ''))[offset:offset+limit]
        stories = Feed.format_stories(mstories) 
    elif usersub and (read_filter == 'unread' or order == 'oldest'):
        stories = usersub.get_stories(order=order, read_filter=read_filter, offset=offset, limit=limit,
                                      default_cutoff_date=user.profile.unread_cutoff)
    else:
        stories = feed.get_stories(offset, limit)
    
    checkpoint1 = time.time()
    
    try:
        stories, user_profiles = MSharedStory.stories_with_comments_and_profiles(stories, user.pk)
    except redis.ConnectionError:
        logging.user(request, "~BR~FK~SBRedis is unavailable for shared stories.")

    checkpoint2 = time.time()
    
    # Get intelligence classifier for user
    
    if usersub and usersub.is_trained:
        classifier_feeds   = list(MClassifierFeed.objects(user_id=user.pk, feed_id=feed_id, social_user_id=0))
        classifier_authors = list(MClassifierAuthor.objects(user_id=user.pk, feed_id=feed_id))
        classifier_titles  = list(MClassifierTitle.objects(user_id=user.pk, feed_id=feed_id))
        classifier_tags    = list(MClassifierTag.objects(user_id=user.pk, feed_id=feed_id))
    else:
        classifier_feeds = []
        classifier_authors = []
        classifier_titles = []
        classifier_tags = []
    classifiers = get_classifiers_for_user(user, feed_id=feed_id, 
                                           classifier_feeds=classifier_feeds, 
                                           classifier_authors=classifier_authors, 
                                           classifier_titles=classifier_titles,
                                           classifier_tags=classifier_tags)
    checkpoint3 = time.time()
    
    unread_story_hashes = []
    if stories:
        if (read_filter == 'all' or query) and usersub:
            unread_story_hashes = UserSubscription.story_hashes(user.pk, read_filter='unread',
                                                      feed_ids=[usersub.feed_id],
                                                      usersubs=[usersub],
                                                      group_by_feed=False,
                                                      cutoff_date=user.profile.unread_cutoff)
        story_hashes = [story['story_hash'] for story in stories if story['story_hash']]
        starred_stories = MStarredStory.objects(user_id=user.pk, 
                                                story_feed_id=feed.pk, 
                                                story_hash__in=story_hashes)\
                                       .only('story_hash', 'starred_date', 'user_tags')
        shared_story_hashes = MSharedStory.check_shared_story_hashes(user.pk, story_hashes)
        shared_stories = []
        if shared_story_hashes:
            shared_stories = MSharedStory.objects(user_id=user.pk, 
                                                  story_hash__in=shared_story_hashes)\
                                         .only('story_hash', 'shared_date', 'comments')
        starred_stories = dict([(story.story_hash, dict(starred_date=story.starred_date,
                                                        user_tags=story.user_tags))
                                for story in starred_stories])
        shared_stories = dict([(story.story_hash, dict(shared_date=story.shared_date,
                                                       comments=story.comments))
                               for story in shared_stories])
            
    checkpoint4 = time.time()
    
    for story in stories:
        if not include_story_content:
            del story['story_content']
        story_date = localtime_for_timezone(story['story_date'], user.profile.timezone)
        nowtz = localtime_for_timezone(now, user.profile.timezone)
        story['short_parsed_date'] = format_story_link_date__short(story_date, nowtz)
        story['long_parsed_date'] = format_story_link_date__long(story_date, nowtz)
        if usersub:
            story['read_status'] = 1
            if (read_filter == 'all' or query) and usersub:
                story['read_status'] = 1 if story['story_hash'] not in unread_story_hashes else 0
            elif read_filter == 'unread' and usersub:
                story['read_status'] = 0
            if story['story_hash'] in starred_stories:
                story['starred'] = True
                starred_date = localtime_for_timezone(starred_stories[story['story_hash']]['starred_date'],
                                                      user.profile.timezone)
                story['starred_date'] = format_story_link_date__long(starred_date, now)
                story['starred_timestamp'] = starred_date.strftime('%s')
                story['user_tags'] = starred_stories[story['story_hash']]['user_tags']
            if story['story_hash'] in shared_stories:
                story['shared'] = True
                shared_date = localtime_for_timezone(shared_stories[story['story_hash']]['shared_date'],
                                                     user.profile.timezone)
                story['shared_date'] = format_story_link_date__long(shared_date, now)
                story['shared_comments'] = strip_tags(shared_stories[story['story_hash']]['comments'])
        else:
            story['read_status'] = 1
        story['intelligence'] = {
            'feed': apply_classifier_feeds(classifier_feeds, feed),
            'author': apply_classifier_authors(classifier_authors, story),
            'tags': apply_classifier_tags(classifier_tags, story),
            'title': apply_classifier_titles(classifier_titles, story),
        }
        story['score'] = UserSubscription.score_story(story['intelligence'])
        
    # Intelligence
    feed_tags = json.decode(feed.data.popular_tags) if feed.data.popular_tags else []
    feed_authors = json.decode(feed.data.popular_authors) if feed.data.popular_authors else []
    
    if usersub:
        usersub.feed_opens += 1
        usersub.needs_unread_recalc = True
        usersub.save(update_fields=['feed_opens', 'needs_unread_recalc'])
    
    diff1 = checkpoint1-start
    diff2 = checkpoint2-start
    diff3 = checkpoint3-start
    diff4 = checkpoint4-start
    timediff = time.time()-start
    last_update = relative_timesince(feed.last_update)
    time_breakdown = ""
    if timediff > 1 or settings.DEBUG:
        time_breakdown = "~SN~FR(~SB%.4s/%.4s/%.4s/%.4s~SN)" % (
                          diff1, diff2, diff3, diff4)
    
    search_log = "~SN~FG(~SB%s~SN) " % query if query else ""
    logging.user(request, "~FYLoading feed: ~SB%s%s (%s/%s) %s%s" % (
        feed.feed_title[:22], ('~SN/p%s' % page) if page > 1 else '', order, read_filter, search_log, time_breakdown))

    if not include_hidden:
        hidden_stories_removed = 0
        new_stories = []
        for story in stories:
            if story['score'] >= 0:
                new_stories.append(story)
            else:
                hidden_stories_removed += 1
        stories = new_stories
    
    data = dict(stories=stories, 
                user_profiles=user_profiles,
                feed_tags=feed_tags, 
                feed_authors=feed_authors, 
                classifiers=classifiers,
                updated=last_update,
                user_search=user_search,
                feed_id=feed.pk,
                elapsed_time=round(float(timediff), 2),
                message=message)
    
    if not include_hidden: data['hidden_stories_removed'] = hidden_stories_removed
    if dupe_feed_id: data['dupe_feed_id'] = dupe_feed_id
    if not usersub:
        data.update(feed.canonical())
    # if not usersub and feed.num_subscribers <= 1:
    #     data = dict(code=-1, message="You must be subscribed to this feed.")
    
    # if page <= 3:
    #     import random
    #     time.sleep(random.randint(2, 4))
    
    # if page == 2:
    #     assert False

    return data

def load_feed_page(request, feed_id):
    if not feed_id:
        raise Http404
    
    feed = Feed.get_by_id(feed_id)
    
    if feed and feed.has_page and not feed.has_page_exception:
        if settings.BACKED_BY_AWS.get('pages_on_node'):
            url = "http://%s/original_page/%s" % (
                settings.ORIGINAL_PAGE_SERVER,
                feed.pk,
            )
            page_response = requests.get(url)
            if page_response.status_code == 200:
                response = HttpResponse(page_response.content, mimetype="text/html; charset=utf-8")
                response['Content-Encoding'] = 'gzip'
                response['Last-Modified'] = page_response.headers.get('Last-modified')
                response['Etag'] = page_response.headers.get('Etag')
                response['Content-Length'] = str(len(page_response.content))
                logging.user(request, "~FYLoading original page, proxied from node: ~SB%s bytes" %
                             (len(page_response.content)))
                return response
        
        if settings.BACKED_BY_AWS['pages_on_s3'] and feed.s3_page:
            if settings.PROXY_S3_PAGES:
                key = settings.S3_PAGES_BUCKET.get_key(feed.s3_pages_key)
                if key:
                    compressed_data = key.get_contents_as_string()
                    response = HttpResponse(compressed_data, mimetype="text/html; charset=utf-8")
                    response['Content-Encoding'] = 'gzip'
            
                    logging.user(request, "~FYLoading original page, proxied: ~SB%s bytes" %
                                 (len(compressed_data)))
                    return response
            else:
                logging.user(request, "~FYLoading original page, non-proxied")
                return HttpResponseRedirect('//%s/%s' % (settings.S3_PAGES_BUCKET_NAME,
                                                         feed.s3_pages_key))
    
    data = MFeedPage.get_data(feed_id=feed_id)
    
    if not data or not feed or not feed.has_page or feed.has_page_exception:
        logging.user(request, "~FYLoading original page, ~FRmissing")
        return render(request, 'static/404_original_page.xhtml', {}, 
            content_type='text/html',
            status=404)
    
    logging.user(request, "~FYLoading original page, from the db")
    return HttpResponse(data, mimetype="text/html; charset=utf-8")

@json.json_view
def load_starred_stories(request):
    user         = get_user(request)
    offset       = int(request.REQUEST.get('offset', 0))
    limit        = int(request.REQUEST.get('limit', 10))
    page         = int(request.REQUEST.get('page', 0))
    query        = request.REQUEST.get('query')
    order        = request.REQUEST.get('order', 'newest')
    tag          = request.REQUEST.get('tag')
    story_hashes = request.REQUEST.getlist('h')[:100]
    version      = int(request.REQUEST.get('v', 1))
    now          = localtime_for_timezone(datetime.datetime.now(), user.profile.timezone)
    message      = None
    order_by     = '-' if order == "newest" else ""
    if page: offset = limit * (page - 1)
    
    if query:
        # results = SearchStarredStory.query(user.pk, query)                                                            
        # story_ids = [result.db_id for result in results]                                                          
        if user.profile.is_premium:
            stories = MStarredStory.find_stories(query, user.pk, tag=tag, offset=offset, limit=limit,
                                                 order=order)
        else:
            stories = []
            message = "You must be a premium subscriber to search."
    elif tag:
        if user.profile.is_premium:
            mstories = MStarredStory.objects(
                user_id=user.pk,
                user_tags__contains=tag
            ).order_by('%sstarred_date' % order_by)[offset:offset+limit]
            stories = Feed.format_stories(mstories)        
        else:
            stories = []
            message = "You must be a premium subscriber to read saved stories by tag."
    elif story_hashes:
        mstories = MStarredStory.objects(
            user_id=user.pk,
            story_hash__in=story_hashes
        ).order_by('%sstarred_date' % order_by)[offset:offset+limit]
        stories = Feed.format_stories(mstories)
    else:
        mstories = MStarredStory.objects(
            user_id=user.pk
        ).order_by('%sstarred_date' % order_by)[offset:offset+limit]
        stories = Feed.format_stories(mstories)
    
    stories, user_profiles = MSharedStory.stories_with_comments_and_profiles(stories, user.pk, check_all=True)
    
    story_hashes   = [story['story_hash'] for story in stories]
    story_feed_ids = list(set(s['story_feed_id'] for s in stories))
    usersub_ids    = UserSubscription.objects.filter(user__pk=user.pk, feed__pk__in=story_feed_ids).values('feed__pk')
    usersub_ids    = [us['feed__pk'] for us in usersub_ids]
    unsub_feed_ids = list(set(story_feed_ids).difference(set(usersub_ids)))
    unsub_feeds    = Feed.objects.filter(pk__in=unsub_feed_ids)
    unsub_feeds    = dict((feed.pk, feed.canonical(include_favicon=False)) for feed in unsub_feeds)
    shared_story_hashes = MSharedStory.check_shared_story_hashes(user.pk, story_hashes)
    shared_stories = []
    if shared_story_hashes:
        shared_stories = MSharedStory.objects(user_id=user.pk, 
                                              story_hash__in=shared_story_hashes)\
                                     .only('story_hash', 'shared_date', 'comments')
    shared_stories = dict([(story.story_hash, dict(shared_date=story.shared_date,
                                                   comments=story.comments))
                           for story in shared_stories])

    nowtz = localtime_for_timezone(now, user.profile.timezone)
    for story in stories:
        story_date                 = localtime_for_timezone(story['story_date'], user.profile.timezone)
        story['short_parsed_date'] = format_story_link_date__short(story_date, nowtz)
        story['long_parsed_date']  = format_story_link_date__long(story_date, nowtz)
        starred_date               = localtime_for_timezone(story['starred_date'], user.profile.timezone)
        story['starred_date']      = format_story_link_date__long(starred_date, nowtz)
        story['starred_timestamp'] = starred_date.strftime('%s')
        story['read_status']       = 1
        story['starred']           = True
        story['intelligence']      = {
            'feed':   1,
            'author': 0,
            'tags':   0,
            'title':  0,
        }
        if story['story_hash'] in shared_stories:
            story['shared'] = True
            story['shared_comments'] = strip_tags(shared_stories[story['story_hash']]['comments'])
    
    search_log = "~SN~FG(~SB%s~SN)" % query if query else ""
    logging.user(request, "~FCLoading starred stories: ~SB%s stories %s" % (len(stories), search_log))
    
    return {
        "stories": stories,
        "user_profiles": user_profiles,
        'feeds': unsub_feeds.values() if version == 2 else unsub_feeds,
        "message": message,
    }

@json.json_view
def starred_story_hashes(request):
    user               = get_user(request)
    include_timestamps = is_true(request.REQUEST.get('include_timestamps', False))
    
    mstories = MStarredStory.objects(
        user_id=user.pk
    ).only('story_hash', 'starred_date').order_by('-starred_date')
    
    if include_timestamps:
        story_hashes = [(s.story_hash, s.starred_date.strftime("%s")) for s in mstories]
    else:
        story_hashes = [s.story_hash for s in mstories]
    
    logging.user(request, "~FYLoading ~FCstarred story hashes~FY: %s story hashes" % 
                           (len(story_hashes)))

    return dict(starred_story_hashes=story_hashes)

def starred_stories_rss_feed(request, user_id, secret_token, tag_slug):
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        raise Http404
    
    try:
        tag_counts = MStarredStoryCounts.objects.get(user_id=user_id, slug=tag_slug)
    except MStarredStoryCounts.MultipleObjectsReturned:
        tag_counts = MStarredStoryCounts.objects(user_id=user_id, slug=tag_slug).first()
    except MStarredStoryCounts.DoesNotExist:
        raise Http404
    
    data = {}
    data['title'] = "Saved Stories - %s" % tag_counts.tag
    data['link'] = "%s%s" % (
        settings.NEWSBLUR_URL,
        reverse('saved-stories-tag', kwargs=dict(tag_name=tag_slug)))
    data['description'] = "Stories saved by %s on NewsBlur with the tag \"%s\"." % (user.username,
                                                                                    tag_counts.tag)
    data['lastBuildDate'] = datetime.datetime.utcnow()
    data['generator'] = 'NewsBlur - %s' % settings.NEWSBLUR_URL
    data['docs'] = None
    data['author_name'] = user.username
    data['feed_url'] = "%s%s" % (
        settings.NEWSBLUR_URL,
        reverse('starred-stories-rss-feed', 
                kwargs=dict(user_id=user_id, secret_token=secret_token, tag_slug=tag_slug)),
    )
    rss = feedgenerator.Atom1Feed(**data)

    if not tag_counts.tag:
        starred_stories = MStarredStory.objects(
            user_id=user.pk
        ).order_by('-starred_date').limit(25)
    else:
        starred_stories = MStarredStory.objects(
            user_id=user.pk,
            user_tags__contains=tag_counts.tag
        ).order_by('-starred_date').limit(25)
    for starred_story in starred_stories:
        story_data = {
            'title': starred_story.story_title,
            'link': starred_story.story_permalink,
            'description': (starred_story.story_content_z and
                            zlib.decompress(starred_story.story_content_z)),
            'author_name': starred_story.story_author_name,
            'categories': starred_story.story_tags,
            'unique_id': starred_story.story_guid,
            'pubdate': starred_story.starred_date,
        }
        rss.add_item(**story_data)
        
    logging.user(request, "~FBGenerating ~SB%s~SN's saved story RSS feed (%s, %s stories): ~FM%s" % (
        user.username,
        tag_counts.tag,
        tag_counts.count,
        request.META.get('HTTP_USER_AGENT', "")[:24]
    ))
    return HttpResponse(rss.writeString('utf-8'), content_type='application/rss+xml')

@json.json_view
def load_read_stories(request):
    user   = get_user(request)
    offset = int(request.REQUEST.get('offset', 0))
    limit  = int(request.REQUEST.get('limit', 10))
    page   = int(request.REQUEST.get('page', 0))
    order  = request.REQUEST.get('order', 'newest')
    query  = request.REQUEST.get('query')
    now    = localtime_for_timezone(datetime.datetime.now(), user.profile.timezone)
    message = None
    if page: offset = limit * (page - 1)
    
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
        stories = sorted(stories, key=lambda story: story_hashes.index(story['story_hash']),
                         reverse=bool(order=="oldest"))
    
    stories, user_profiles = MSharedStory.stories_with_comments_and_profiles(stories, user.pk, check_all=True)
    
    story_hashes   = [story['story_hash'] for story in stories]
    story_feed_ids = list(set(s['story_feed_id'] for s in stories))
    usersub_ids    = UserSubscription.objects.filter(user__pk=user.pk, feed__pk__in=story_feed_ids).values('feed__pk')
    usersub_ids    = [us['feed__pk'] for us in usersub_ids]
    unsub_feed_ids = list(set(story_feed_ids).difference(set(usersub_ids)))
    unsub_feeds    = Feed.objects.filter(pk__in=unsub_feed_ids)
    unsub_feeds    = [feed.canonical(include_favicon=False) for feed in unsub_feeds]

    shared_stories = MSharedStory.objects(user_id=user.pk, 
                                          story_hash__in=story_hashes)\
                                 .only('story_hash', 'shared_date', 'comments')
    shared_stories = dict([(story.story_hash, dict(shared_date=story.shared_date,
                                                   comments=story.comments))
                           for story in shared_stories])
    starred_stories = MStarredStory.objects(user_id=user.pk, 
                                            story_hash__in=story_hashes)\
                                   .only('story_hash', 'starred_date')
    starred_stories = dict([(story.story_hash, story.starred_date) 
                            for story in starred_stories])
    
    nowtz = localtime_for_timezone(now, user.profile.timezone)
    for story in stories:
        story_date                 = localtime_for_timezone(story['story_date'], user.profile.timezone)
        story['short_parsed_date'] = format_story_link_date__short(story_date, nowtz)
        story['long_parsed_date']  = format_story_link_date__long(story_date, nowtz)
        story['read_status']       = 1
        story['intelligence']      = {
            'feed':   1,
            'author': 0,
            'tags':   0,
            'title':  0,
        }
        if story['story_hash'] in starred_stories:
            story['starred'] = True
            starred_date = localtime_for_timezone(starred_stories[story['story_hash']],
                                                  user.profile.timezone)
            story['starred_date'] = format_story_link_date__long(starred_date, now)
            story['starred_timestamp'] = starred_date.strftime('%s')
        if story['story_hash'] in shared_stories:
            story['shared'] = True
            story['shared_comments'] = strip_tags(shared_stories[story['story_hash']]['comments'])
    
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
    limit             = 12
    start             = time.time()
    user              = get_user(request)
    message           = None
    feed_ids          = [int(feed_id) for feed_id in request.REQUEST.getlist('feeds') if feed_id]
    if not feed_ids:
        feed_ids      = [int(feed_id) for feed_id in request.REQUEST.getlist('f') if feed_id]
    story_hashes      = request.REQUEST.getlist('h')[:100]
    original_feed_ids = list(feed_ids)
    page              = int(request.REQUEST.get('page', 1))
    order             = request.REQUEST.get('order', 'newest')
    read_filter       = request.REQUEST.get('read_filter', 'unread')
    query             = request.REQUEST.get('query')
    include_hidden    = is_true(request.REQUEST.get('include_hidden', False))
    now               = localtime_for_timezone(datetime.datetime.now(), user.profile.timezone)
    usersubs          = []
    code              = 1
    user_search       = None
    offset = (page-1) * limit
    limit = page * limit
    story_date_order = "%sstory_date" % ('' if order == 'oldest' else '-')
    
    if story_hashes:
        unread_feed_story_hashes = None
        read_filter = 'unread'
        mstories = MStory.objects(story_hash__in=story_hashes).order_by(story_date_order)
        stories = Feed.format_stories(mstories)
    elif query:
        if user.profile.is_premium:
            user_search = MUserSearch.get_user(user.pk)
            user_search.touch_search_date()
            usersubs = UserSubscription.subs_for_feeds(user.pk, feed_ids=feed_ids,
                                                       read_filter='all')
            feed_ids = [sub.feed_id for sub in usersubs]
            stories = Feed.find_feed_stories(feed_ids, query, order=order, offset=offset, limit=limit)
            mstories = stories
            unread_feed_story_hashes = UserSubscription.story_hashes(user.pk, feed_ids=feed_ids, 
                                                                     read_filter="unread", order=order, 
                                                                     group_by_feed=False, 
                                                                     cutoff_date=user.profile.unread_cutoff)
        else:
            stories = []
            mstories = []
            message = "You must be a premium subscriber to search."
    elif read_filter == 'starred':
        mstories = MStarredStory.objects(
            user_id=user.pk,
            story_feed_id__in=feed_ids
        ).order_by('%sstarred_date' % ('-' if order == 'newest' else ''))[offset:offset+limit]
        stories = Feed.format_stories(mstories) 
    else:
        usersubs = UserSubscription.subs_for_feeds(user.pk, feed_ids=feed_ids,
                                                   read_filter=read_filter)
        all_feed_ids = [f for f in feed_ids]
        feed_ids = [sub.feed_id for sub in usersubs]
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
            }
            story_hashes, unread_feed_story_hashes = UserSubscription.feed_stories(**params)
        else:
            story_hashes = []
            unread_feed_story_hashes = []

        mstories = MStory.objects(story_hash__in=story_hashes).order_by(story_date_order)
        stories = Feed.format_stories(mstories)
    
    found_feed_ids = list(set([story['story_feed_id'] for story in stories]))
    stories, user_profiles = MSharedStory.stories_with_comments_and_profiles(stories, user.pk)
    
    if not usersubs:
        usersubs = UserSubscription.subs_for_feeds(user.pk, feed_ids=found_feed_ids,
                                                   read_filter=read_filter)

    trained_feed_ids = [sub.feed_id for sub in usersubs if sub.is_trained]
    found_trained_feed_ids = list(set(trained_feed_ids) & set(found_feed_ids))

    # Find starred stories
    if found_feed_ids:
        if read_filter == 'starred':
            starred_stories = mstories
        else:
            starred_stories = MStarredStory.objects(
                user_id=user.pk,
                story_feed_id__in=found_feed_ids
            ).only('story_hash', 'starred_date')
        starred_stories = dict([(story.story_hash, dict(starred_date=story.starred_date,
                                                        user_tags=story.user_tags)) 
                                for story in starred_stories])
    else:
        starred_stories = {}
    
    # Intelligence classifiers for all feeds involved
    if found_trained_feed_ids:
        classifier_feeds = list(MClassifierFeed.objects(user_id=user.pk,
                                                        feed_id__in=found_trained_feed_ids,
                                                        social_user_id=0))
        classifier_authors = list(MClassifierAuthor.objects(user_id=user.pk, 
                                                            feed_id__in=found_trained_feed_ids))
        classifier_titles = list(MClassifierTitle.objects(user_id=user.pk, 
                                                          feed_id__in=found_trained_feed_ids))
        classifier_tags = list(MClassifierTag.objects(user_id=user.pk, 
                                                      feed_id__in=found_trained_feed_ids))
    else:
        classifier_feeds = []
        classifier_authors = []
        classifier_titles = []
        classifier_tags = []
    classifiers = sort_classifiers_by_feed(user=user, feed_ids=found_feed_ids,
                                           classifier_feeds=classifier_feeds,
                                           classifier_authors=classifier_authors,
                                           classifier_titles=classifier_titles,
                                           classifier_tags=classifier_tags)
    
    # Just need to format stories
    nowtz = localtime_for_timezone(now, user.profile.timezone)
    for story in stories:
        if read_filter == 'starred':
            story['read_status'] = 1
        else:
            story['read_status'] = 0
        if read_filter == 'all' or query:
            if (unread_feed_story_hashes is not None and 
                story['story_hash'] not in unread_feed_story_hashes):
                story['read_status'] = 1
        story_date = localtime_for_timezone(story['story_date'], user.profile.timezone)
        story['short_parsed_date'] = format_story_link_date__short(story_date, nowtz)
        story['long_parsed_date']  = format_story_link_date__long(story_date, nowtz)
        if story['story_hash'] in starred_stories:
            story['starred'] = True
            starred_date = localtime_for_timezone(starred_stories[story['story_hash']]['starred_date'],
                                                  user.profile.timezone)
            story['starred_date'] = format_story_link_date__long(starred_date, now)
            story['starred_timestamp'] = starred_date.strftime('%s')
            story['user_tags'] = starred_stories[story['story_hash']]['user_tags']
        story['intelligence'] = {
            'feed':   apply_classifier_feeds(classifier_feeds, story['story_feed_id']),
            'author': apply_classifier_authors(classifier_authors, story),
            'tags':   apply_classifier_tags(classifier_tags, story),
            'title':  apply_classifier_titles(classifier_titles, story),
        }
        story['score'] = UserSubscription.score_story(story['intelligence'])
        
    
    if not user.profile.is_premium:
        message = "The full River of News is a premium feature."
        code = 0
        # if page > 1:
        #     stories = []
        # else:
        #     stories = stories[:5]
    diff = time.time() - start
    timediff = round(float(diff), 2)
    logging.user(request, "~FYLoading ~FCriver stories~FY: ~SBp%s~SN (%s/%s "
                               "stories, ~SN%s/%s/%s feeds, %s/%s)" % 
                               (page, len(stories), len(mstories), len(found_feed_ids), 
                               len(feed_ids), len(original_feed_ids), order, read_filter))


    if not include_hidden:
        hidden_stories_removed = 0
        new_stories = []
        for story in stories:
            if story['score'] >= 0:
                new_stories.append(story)
            else:
                hidden_stories_removed += 1
        stories = new_stories
    
    # if page <= 1:
    #     import random
    #     time.sleep(random.randint(0, 6))
    
    data = dict(code=code,
                message=message,
                stories=stories,
                classifiers=classifiers, 
                elapsed_time=timediff, 
                user_search=user_search, 
                user_profiles=user_profiles)
                
    if not include_hidden: data['hidden_stories_removed'] = hidden_stories_removed
    
    return data
    

@json.json_view
def unread_story_hashes__old(request):
    user              = get_user(request)
    feed_ids          = [int(feed_id) for feed_id in request.REQUEST.getlist('feed_id') if feed_id]
    include_timestamps = is_true(request.REQUEST.get('include_timestamps', False))
    usersubs = {}
    
    if not feed_ids:
        usersubs = UserSubscription.objects.filter(Q(unread_count_neutral__gt=0) |
                                                   Q(unread_count_positive__gt=0),
                                                   user=user, active=True)
        feed_ids = [sub.feed_id for sub in usersubs]
    else:
        usersubs = UserSubscription.objects.filter(Q(unread_count_neutral__gt=0) |
                                                   Q(unread_count_positive__gt=0),
                                                   user=user, active=True, feed__in=feed_ids)
    
    unread_feed_story_hashes = {}
    story_hash_count = 0
    
    usersubs = dict((sub.feed_id, sub) for sub in usersubs)
    for feed_id in feed_ids:
        if feed_id in usersubs:
            us = usersubs[feed_id]
        else:
            continue
        if not us.unread_count_neutral and not us.unread_count_positive:
            continue
        unread_feed_story_hashes[feed_id] = us.get_stories(read_filter='unread', limit=500,
                                                           withscores=include_timestamps,
                                                           hashes_only=True,
                                                           default_cutoff_date=user.profile.unread_cutoff)
        story_hash_count += len(unread_feed_story_hashes[feed_id])

    logging.user(request, "~FYLoading ~FCunread story hashes~FY: ~SB%s feeds~SN (%s story hashes)" % 
                           (len(feed_ids), len(story_hash_count)))

    return dict(unread_feed_story_hashes=unread_feed_story_hashes)

@json.json_view
def unread_story_hashes(request):
    user               = get_user(request)
    feed_ids           = [int(feed_id) for feed_id in request.REQUEST.getlist('feed_id') if feed_id]
    include_timestamps = is_true(request.REQUEST.get('include_timestamps', False))
    order              = request.REQUEST.get('order', 'newest')
    read_filter        = request.REQUEST.get('read_filter', 'unread')
    
    story_hashes = UserSubscription.story_hashes(user.pk, feed_ids=feed_ids, 
                                                 order=order, read_filter=read_filter,
                                                 include_timestamps=include_timestamps,
                                                 cutoff_date=user.profile.unread_cutoff)
    logging.user(request, "~FYLoading ~FCunread story hashes~FY: ~SB%s feeds~SN (%s story hashes)" % 
                           (len(feed_ids), len(story_hashes)))
    return dict(unread_feed_story_hashes=story_hashes)

@ajax_login_required
@json.json_view
def mark_all_as_read(request):
    code = 1
    try:
        days = int(request.REQUEST.get('days', 0))
    except ValueError:
        return dict(code=-1, message="Days parameter must be an integer, not: %s" %
                    request.REQUEST.get('days'))
    read_date = datetime.datetime.utcnow() - datetime.timedelta(days=days)
    
    feeds = UserSubscription.objects.filter(user=request.user)
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
    
    logging.user(request, "~FMMarking all as read: ~SB%s days" % (days,))
    return dict(code=code)
    
@ajax_login_required
@json.json_view
def mark_story_as_read(request):
    story_ids = request.REQUEST.getlist('story_id')
    try:
        feed_id = int(get_argument_or_404(request, 'feed_id'))
    except ValueError:
        return dict(code=-1, errors=["You must pass a valid feed_id: %s" %
                                     request.REQUEST.get('feed_id')])
    
    try:
        usersub = UserSubscription.objects.select_related('feed').get(user=request.user, feed=feed_id)
    except Feed.DoesNotExist:
        duplicate_feed = DuplicateFeed.objects.filter(duplicate_feed_id=feed_id)
        if duplicate_feed:
            feed_id = duplicate_feed[0].feed_id
            try:
                usersub = UserSubscription.objects.get(user=request.user, 
                                                       feed=duplicate_feed[0].feed)
            except (Feed.DoesNotExist):
                return dict(code=-1, errors=["No feed exists for feed_id %d." % feed_id])
        else:
            return dict(code=-1, errors=["No feed exists for feed_id %d." % feed_id])
    except UserSubscription.DoesNotExist:
        usersub = None
        
    if usersub:
        data = usersub.mark_story_ids_as_read(story_ids, request=request)
    else:
        data = dict(code=-1, errors=["User is not subscribed to this feed."])

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, 'feed:%s' % feed_id)

    return data

@ajax_login_required
@json.json_view
def mark_story_hashes_as_read(request):
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    story_hashes = request.REQUEST.getlist('story_hash')
    
    feed_ids, friend_ids = RUserStory.mark_story_hashes_read(request.user.pk, story_hashes)
    
    if friend_ids:
        socialsubs = MSocialSubscription.objects.filter(
                        user_id=request.user.pk,
                        subscription_user_id__in=friend_ids)
        for socialsub in socialsubs:
            if not socialsub.needs_unread_recalc:
                socialsub.needs_unread_recalc = True
                socialsub.save()
            r.publish(request.user.username, 'social:%s' % socialsub.subscription_user_id)

    # Also count on original subscription
    for feed_id in feed_ids:
        usersubs = UserSubscription.objects.filter(user=request.user.pk, feed=feed_id)
        if usersubs:
            usersub = usersubs[0]
            if not usersub.needs_unread_recalc:
                usersub.needs_unread_recalc = True
                usersub.save(update_fields=['needs_unread_recalc'])
            r.publish(request.user.username, 'feed:%s' % feed_id)
    
    hash_count = len(story_hashes)
    logging.user(request, "~FYRead %s %s in feed/socialsubs: %s/%s" % (
                 hash_count, 'story' if hash_count == 1 else 'stories', feed_ids, friend_ids))

    return dict(code=1, story_hashes=story_hashes, 
                feed_ids=feed_ids, friend_user_ids=friend_ids)

@ajax_login_required
@json.json_view
def mark_feed_stories_as_read(request):
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    feeds_stories = request.REQUEST.get('feeds_stories', "{}")
    feeds_stories = json.decode(feeds_stories)
    data = {
        'code': -1,
        'message': 'Nothing was marked as read'
    }
    
    for feed_id, story_ids in feeds_stories.items():
        try:
            feed_id = int(feed_id)
        except ValueError:
            continue
        try:
            usersub = UserSubscription.objects.select_related('feed').get(user=request.user, feed=feed_id)
            data = usersub.mark_story_ids_as_read(story_ids, request=request)
        except UserSubscription.DoesNotExist:
            return dict(code=-1, error="You are not subscribed to this feed_id: %d" % feed_id)
        except Feed.DoesNotExist:
            duplicate_feed = DuplicateFeed.objects.filter(duplicate_feed_id=feed_id)
            try:
                if not duplicate_feed: raise Feed.DoesNotExist
                usersub = UserSubscription.objects.get(user=request.user, 
                                                       feed=duplicate_feed[0].feed)
                data = usersub.mark_story_ids_as_read(story_ids, request=request)
            except (UserSubscription.DoesNotExist, Feed.DoesNotExist):
                return dict(code=-1, error="No feed exists for feed_id: %d" % feed_id)

        r.publish(request.user.username, 'feed:%s' % feed_id)
    
    return data
    
@ajax_login_required
@json.json_view
def mark_social_stories_as_read(request):
    code = 1
    errors = []
    data = {}
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    users_feeds_stories = request.REQUEST.get('users_feeds_stories', "{}")
    users_feeds_stories = json.decode(users_feeds_stories)

    for social_user_id, feeds in users_feeds_stories.items():
        for feed_id, story_ids in feeds.items():
            feed_id = int(feed_id)
            try:
                socialsub = MSocialSubscription.objects.get(user_id=request.user.pk, 
                                                            subscription_user_id=social_user_id)
                data = socialsub.mark_story_ids_as_read(story_ids, feed_id, request=request)
            except OperationError, e:
                code = -1
                errors.append("Already read story: %s" % e)
            except MSocialSubscription.DoesNotExist:
                MSocialSubscription.mark_unsub_story_ids_as_read(request.user.pk, social_user_id,
                                                                 story_ids, feed_id,
                                                                 request=request)
            except Feed.DoesNotExist:
                duplicate_feed = DuplicateFeed.objects.filter(duplicate_feed_id=feed_id)
                if duplicate_feed:
                    try:
                        socialsub = MSocialSubscription.objects.get(user_id=request.user.pk,
                                                                    subscription_user_id=social_user_id)
                        data = socialsub.mark_story_ids_as_read(story_ids, duplicate_feed[0].feed.pk, request=request)
                    except (UserSubscription.DoesNotExist, Feed.DoesNotExist):
                        code = -1
                        errors.append("No feed exists for feed_id %d." % feed_id)
                else:
                    continue
            r.publish(request.user.username, 'feed:%s' % feed_id)
        r.publish(request.user.username, 'social:%s' % social_user_id)

    data.update(code=code, errors=errors)
    return data
    
@required_params('story_id', feed_id=int)
@ajax_login_required
@json.json_view
def mark_story_as_unread(request):
    story_id = request.REQUEST.get('story_id', None)
    feed_id = int(request.REQUEST.get('feed_id', 0))
    
    try:
        usersub = UserSubscription.objects.select_related('feed').get(user=request.user, feed=feed_id)
        feed = usersub.feed
    except UserSubscription.DoesNotExist:
        usersub = None
        feed = Feed.get_by_id(feed_id)
        
    if usersub and not usersub.needs_unread_recalc:
        usersub.needs_unread_recalc = True
        usersub.save(update_fields=['needs_unread_recalc'])
        
    data = dict(code=0, payload=dict(story_id=story_id))
    
    story, found_original = MStory.find_story(feed_id, story_id)
    
    if not story:
        logging.user(request, "~FY~SBUnread~SN story in feed: %s (NOT FOUND)" % (feed))
        return dict(code=-1, message="Story not found.")
    
    if usersub:
        data = usersub.invert_read_stories_after_unread_story(story, request)

    message = RUserStory.story_can_be_marked_read_by_user(story, request.user)
    if message:
        data['code'] = -1
        data['message'] = message
        return data
    
    social_subs = MSocialSubscription.mark_dirty_sharing_story(user_id=request.user.pk, 
                                                               story_feed_id=feed_id, 
                                                               story_guid_hash=story.guid_hash)
    dirty_count = social_subs and social_subs.count()
    dirty_count = ("(%s social_subs)" % dirty_count) if dirty_count else ""
    RUserStory.mark_story_hash_unread(user_id=request.user.pk, story_hash=story.story_hash)
    
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, 'feed:%s' % feed_id)

    logging.user(request, "~FY~SBUnread~SN story in feed: %s %s" % (feed, dirty_count))
    
    return data

@ajax_login_required
@json.json_view
@required_params('story_hash')
def mark_story_hash_as_unread(request):
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    story_hash = request.REQUEST.get('story_hash')
    feed_id, _ = MStory.split_story_hash(story_hash)
    story, _ = MStory.find_story(feed_id, story_hash)
    if not story:
        data = dict(code=-1, message="That story has been removed from the feed, no need to mark it unread.")
        return data        
    message = RUserStory.story_can_be_marked_read_by_user(story, request.user)
    if message:
        data = dict(code=-1, message=message)
        return data
    
    # Also count on original subscription
    usersubs = UserSubscription.objects.filter(user=request.user.pk, feed=feed_id)
    if usersubs:
        usersub = usersubs[0]
        if not usersub.needs_unread_recalc:
            usersub.needs_unread_recalc = True
            usersub.save(update_fields=['needs_unread_recalc'])
        data = usersub.invert_read_stories_after_unread_story(story, request)
        r.publish(request.user.username, 'feed:%s' % feed_id)

    feed_id, friend_ids = RUserStory.mark_story_hash_unread(request.user.pk, story_hash)

    if friend_ids:
        socialsubs = MSocialSubscription.objects.filter(
                        user_id=request.user.pk,
                        subscription_user_id__in=friend_ids)
        for socialsub in socialsubs:
            if not socialsub.needs_unread_recalc:
                socialsub.needs_unread_recalc = True
                socialsub.save()
            r.publish(request.user.username, 'social:%s' % socialsub.subscription_user_id)

    logging.user(request, "~FYUnread story in feed/socialsubs: %s/%s" % (feed_id, friend_ids))

    return dict(code=1, story_hash=story_hash, feed_id=feed_id, friend_user_ids=friend_ids)

@ajax_login_required
@json.json_view
def mark_feed_as_read(request):
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    feed_ids = request.REQUEST.getlist('feed_id')
    cutoff_timestamp = int(request.REQUEST.get('cutoff_timestamp', 0))
    direction = request.REQUEST.get('direction', 'older')
    multiple = len(feed_ids) > 1
    code = 1
    errors = []
    cutoff_date = datetime.datetime.fromtimestamp(cutoff_timestamp) if cutoff_timestamp else None
    
    for feed_id in feed_ids:
        if 'social:' in feed_id:
            user_id = int(feed_id.replace('social:', ''))
            try:
                sub = MSocialSubscription.objects.get(user_id=request.user.pk, 
                                                      subscription_user_id=user_id)
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
            except (Feed.DoesNotExist, UserSubscription.DoesNotExist), e:
                errors.append("User not subscribed: %s" % e)
                continue
            except (ValueError), e:
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
                r.publish(request.user.username, 'feed:%s' % feed_id)
        except IntegrityError, e:
            errors.append("Could not mark feed as read: %s" % e)
            code = -1
            
    if multiple:
        logging.user(request, "~FMMarking ~SB%s~SN feeds as read" % len(feed_ids))
        r.publish(request.user.username, 'refresh:%s' % ','.join(feed_ids))
    
    if errors:
        logging.user(request, "~FMMarking read had errors: ~FR%s" % errors)
    
    return dict(code=code, errors=errors, cutoff_date=cutoff_date, direction=direction)

def _parse_user_info(user):
    return {
        'user_info': {
            'is_anonymous': json.encode(user.is_anonymous()),
            'is_authenticated': json.encode(user.is_authenticated()),
            'username': json.encode(user.username if user.is_authenticated() else 'Anonymous')
        }
    }

@ajax_login_required
@json.json_view
def add_url(request):
    code = 0
    url = request.POST['url']
    folder = request.POST.get('folder', '')
    new_folder = request.POST.get('new_folder')
    auto_active = is_true(request.POST.get('auto_active', 1))
    skip_fetch = is_true(request.POST.get('skip_fetch', False))
    feed = None
    
    if not url:
        code = -1
        message = 'Enter in the website address or the feed URL.'
    elif any([(banned_url in url) for banned_url in BANNED_URLS]):
        code = -1
        message = "The publisher of this website has banned NewsBlur."
    else:
        if new_folder:
            usf, _ = UserSubscriptionFolders.objects.get_or_create(user=request.user)
            usf.add_folder(folder, new_folder)
            folder = new_folder

        code, message, us = UserSubscription.add_subscription(user=request.user, feed_address=url, 
                                                             folder=folder, auto_active=auto_active,
                                                             skip_fetch=skip_fetch)
        feed = us and us.feed
        if feed:
            r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
            r.publish(request.user.username, 'reload:%s' % feed.pk)
            MUserSearch.schedule_index_feeds_for_search(feed.pk, request.user.pk)
        
    return dict(code=code, message=message, feed=feed)

@ajax_login_required
@json.json_view
def add_folder(request):
    folder = request.POST['folder']
    parent_folder = request.POST.get('parent_folder', '')
    folders = None
    logging.user(request, "~FRAdding Folder: ~SB%s (in %s)" % (folder, parent_folder))
    
    if folder:
        code = 1
        message = ""
        user_sub_folders_object, _ = UserSubscriptionFolders.objects.get_or_create(user=request.user)
        user_sub_folders_object.add_folder(parent_folder, folder)
        folders = json.decode(user_sub_folders_object.folders)
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        r.publish(request.user.username, 'reload:feeds')
    else:
        code = -1
        message = "Gotta write in a folder name."
        
    return dict(code=code, message=message, folders=folders)

@ajax_login_required
@json.json_view
def delete_feed(request):
    feed_id = int(request.POST['feed_id'])
    in_folder = request.POST.get('in_folder', None)
    if not in_folder or in_folder == ' ':
        in_folder = ""
    
    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders.delete_feed(feed_id, in_folder)
    
    feed = Feed.objects.filter(pk=feed_id)
    if feed:
        feed[0].count_subscribers()
    
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, 'reload:feeds')
    
    return dict(code=1, message="Removed %s from '%s'." % (feed, in_folder))

@ajax_login_required
@json.json_view
def delete_feed_by_url(request):
    message = ""
    code = 0
    url = request.POST['url']
    in_folder = request.POST.get('in_folder', '')
    if in_folder == ' ':
        in_folder = ""
    
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
    folder_to_delete = request.POST.get('folder_name') or request.POST.get('folder_to_delete')
    in_folder = request.POST.get('in_folder', None)
    feed_ids_in_folder = [int(f) for f in request.REQUEST.getlist('feed_id') if f]

    request.user.profile.send_opml_export_email(reason="You have deleted an entire folder of feeds, so here's a backup just in case.")
    
    # Works piss poor with duplicate folder titles, if they are both in the same folder.
    # Deletes all, but only in the same folder parent. But nobody should be doing that, right?
    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders.delete_folder(folder_to_delete, in_folder, feed_ids_in_folder)
    folders = json.decode(user_sub_folders.folders)

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, 'reload:feeds')
    
    return dict(code=1, folders=folders)


@required_params('feeds_by_folder')
@ajax_login_required
@json.json_view
def delete_feeds_by_folder(request):
    feeds_by_folder = json.decode(request.POST['feeds_by_folder'])

    request.user.profile.send_opml_export_email(reason="You have deleted a number of feeds at once, so here's a backup just in case.")
    
    # Works piss poor with duplicate folder titles, if they are both in the same folder.
    # Deletes all, but only in the same folder parent. But nobody should be doing that, right?
    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders.delete_feeds_by_folder(feeds_by_folder)
    folders = json.decode(user_sub_folders.folders)

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, 'reload:feeds')
    
    return dict(code=1, folders=folders)

@ajax_login_required
@json.json_view
def rename_feed(request):
    feed = get_object_or_404(Feed, pk=int(request.POST['feed_id']))
    user_sub = UserSubscription.objects.get(user=request.user, feed=feed)
    feed_title = request.POST['feed_title']
    
    logging.user(request, "~FRRenaming feed '~SB%s~SN' to: ~SB%s" % (
                 feed.feed_title, feed_title))
                 
    user_sub.user_title = feed_title
    user_sub.save()
    
    return dict(code=1)
    
@ajax_login_required
@json.json_view
def rename_folder(request):
    folder_to_rename = request.POST.get('folder_name') or request.POST.get('folder_to_rename')
    new_folder_name = request.POST['new_folder_name']
    in_folder = request.POST.get('in_folder', '')
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
    feed_id = int(request.POST['feed_id'])
    in_folders = request.POST.getlist('in_folders', '')
    to_folders = request.POST.getlist('to_folders', '')

    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders = user_sub_folders.move_feed_to_folders(feed_id, in_folders=in_folders,
                                                             to_folders=to_folders)
    
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, 'reload:feeds')

    return dict(code=1, folders=json.decode(user_sub_folders.folders))
    
@ajax_login_required
@json.json_view
def move_feed_to_folder(request):
    feed_id = int(request.POST['feed_id'])
    in_folder = request.POST.get('in_folder', '')
    to_folder = request.POST.get('to_folder', '')

    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders = user_sub_folders.move_feed_to_folder(feed_id, in_folder=in_folder,
                                                            to_folder=to_folder)
    
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, 'reload:feeds')

    return dict(code=1, folders=json.decode(user_sub_folders.folders))
    
@ajax_login_required
@json.json_view
def move_folder_to_folder(request):
    folder_name = request.POST['folder_name']
    in_folder = request.POST.get('in_folder', '')
    to_folder = request.POST.get('to_folder', '')
    
    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders = user_sub_folders.move_folder_to_folder(folder_name, in_folder=in_folder, to_folder=to_folder)
    
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, 'reload:feeds')

    return dict(code=1, folders=json.decode(user_sub_folders.folders))

@required_params('feeds_by_folder', 'to_folder')
@ajax_login_required
@json.json_view
def move_feeds_by_folder_to_folder(request):
    feeds_by_folder = json.decode(request.POST['feeds_by_folder'])
    to_folder = request.POST['to_folder']
    new_folder = request.POST.get('new_folder', None)

    request.user.profile.send_opml_export_email(reason="You have moved a number of feeds at once, so here's a backup just in case.")
    
    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)

    if new_folder:
        user_sub_folders.add_folder(to_folder, new_folder)
        to_folder = new_folder

    user_sub_folders = user_sub_folders.move_feeds_by_folder_to_folder(feeds_by_folder, to_folder)
    
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, 'reload:feeds')

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
        return HttpResponseRedirect(reverse('index'))
    
    return dict(code=code)
    
@json.json_view
def load_features(request):
    user = get_user(request)
    page = max(int(request.REQUEST.get('page', 0)), 0)
    logging.user(request, "~FBBrowse features: ~SBPage #%s" % (page+1))
    features = Feature.objects.all()[page*3:(page+1)*3+1].values()
    features = [{
        'description': f['description'], 
        'date': localtime_for_timezone(f['date'], user.profile.timezone).strftime("%b %d, %Y")
    } for f in features]
    return features

@ajax_login_required
@json.json_view
def save_feed_order(request):
    folders = request.POST.get('folders')
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
    feed_id = request.REQUEST.get('feed_id')
    user = get_user(request)
    usersubs = UserSubscription.objects.filter(user=user, active=True)
    
    if feed_id:
        feed = get_object_or_404(Feed, pk=feed_id)
        usersubs = usersubs.filter(feed=feed)
    usersubs = usersubs.select_related('feed').order_by('-feed__stories_last_month')
                
    for us in usersubs:
        if (not us.is_trained and us.feed.stories_last_month > 0) or feed_id:
            classifier = dict()
            classifier['classifiers'] = get_classifiers_for_user(user, feed_id=us.feed.pk)
            classifier['feed_id'] = us.feed_id
            classifier['stories_last_month'] = us.feed.stories_last_month
            classifier['num_subscribers'] = us.feed.num_subscribers
            classifier['feed_tags'] = json.decode(us.feed.data.popular_tags) if us.feed.data.popular_tags else []
            classifier['feed_authors'] = json.decode(us.feed.data.popular_authors) if us.feed.data.popular_authors else []
            classifiers.append(classifier)
    
    user.profile.has_trained_intelligence = True
    user.profile.save()
    
    logging.user(user, "~FGLoading Trainer: ~SB%s feeds" % (len(classifiers)))
    
    return classifiers

@ajax_login_required
@json.json_view
def save_feed_chooser(request):
    is_premium = request.user.profile.is_premium
    approved_feeds = [int(feed_id) for feed_id in request.POST.getlist('approved_feeds') if feed_id]
    if not is_premium:
        approved_feeds = approved_feeds[:64]
    activated = 0
    usersubs = UserSubscription.objects.filter(user=request.user)
    
    for sub in usersubs:
        try:
            if sub.feed_id in approved_feeds:
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
    
    request.user.profile.queue_new_feeds()
    request.user.profile.refresh_stale_feeds(exclude_new=True)
    
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(request.user.username, 'reload:feeds')
    
    logging.user(request, "~BB~FW~SBFeed chooser: ~FC%s~SN/~SB%s" % (
        activated, 
        usersubs.count()
    ))
    
    return {'activated': activated}

@ajax_login_required
def retrain_all_sites(request):
    for sub in UserSubscription.objects.filter(user=request.user):
        sub.is_trained = False
        sub.save()
        
    return feeds_trainer(request)
    
@login_required
def activate_premium_account(request):
    try:
        usersubs = UserSubscription.objects.select_related('feed').filter(user=request.user)
        for sub in usersubs:
            sub.active = True
            sub.save()
            if sub.feed.premium_subscribers <= 0:
                sub.feed.count_subscribers()
                sub.feed.schedule_feed_fetch_immediately()
    except Exception, e:
        subject = "Premium activation failed"
        message = "%s -- %s\n\n%s" % (request.user, usersubs, e)
        mail_admins(subject, message, fail_silently=True)
        
    request.user.profile.is_premium = True
    request.user.profile.save()
        
    return HttpResponseRedirect(reverse('index'))

@login_required
def login_as(request):
    if not request.user.is_staff:
        logging.user(request, "~SKNON-STAFF LOGGING IN AS ANOTHER USER!")
        assert False
        return HttpResponseForbidden()
    username = request.GET['user']
    user = get_object_or_404(User, username__iexact=username)
    user.backend = settings.AUTHENTICATION_BACKENDS[0]
    login_user(request, user)
    return HttpResponseRedirect(reverse('index'))
    
def iframe_buster(request):
    logging.user(request, "~FB~SBiFrame bust!")
    return HttpResponse(status=204)

@required_params('story_id', feed_id=int)
@ajax_login_required
@json.json_view
def mark_story_as_starred(request):
    return _mark_story_as_starred(request)
    
@required_params('story_hash')
@ajax_login_required
@json.json_view
def mark_story_hash_as_starred(request):
    return _mark_story_as_starred(request)
    
def _mark_story_as_starred(request):
    code       = 1
    feed_id    = int(request.REQUEST.get('feed_id', 0))
    story_id   = request.REQUEST.get('story_id', None)
    story_hash = request.REQUEST.get('story_hash', None)
    user_tags  = request.REQUEST.getlist('user_tags')
    message    = ""
    if story_hash:
        story, _   = MStory.find_story(story_hash=story_hash)
        feed_id = story and story.story_feed_id
    else:
        story, _   = MStory.find_story(story_feed_id=feed_id, story_id=story_id)
    
    if not story:
        return {'code': -1, 'message': "Could not find story to save."}
        
    story_db = dict([(k, v) for k, v in story._data.items() 
                            if k is not None and v is not None])
    story_db.pop('user_id', None)
    story_db.pop('starred_date', None)
    story_db.pop('id', None)
    story_db.pop('user_tags', None)
    now = datetime.datetime.now()
    story_values = dict(starred_date=now, user_tags=user_tags, **story_db)
    params = dict(story_guid=story.story_guid, user_id=request.user.pk)
    starred_story = MStarredStory.objects(**params).limit(1)
    created = False
    removed_user_tags = []
    if not starred_story:
        params.update(story_values)
        starred_story = MStarredStory.objects.create(**params)
        created = True
        MActivity.new_starred_story(user_id=request.user.pk, 
                                    story_title=story.story_title, 
                                    story_feed_id=feed_id,
                                    story_id=starred_story.story_guid)
        new_user_tags = user_tags
        MStarredStoryCounts.adjust_count(request.user.pk, feed_id=feed_id, amount=1)
    else:
        starred_story = starred_story[0]
        new_user_tags = list(set(user_tags) - set(starred_story.user_tags or []))
        removed_user_tags = list(set(starred_story.user_tags or []) - set(user_tags))
        starred_story.user_tags = user_tags
        starred_story.save()
    
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
    
    if created:
        logging.user(request, "~FCStarring: ~SB%s (~FM~SB%s~FC~SN)" % (story.story_title[:32], starred_story.user_tags))        
    else:
        logging.user(request, "~FCUpdating starred:~SN~FC ~SB%s~SN (~FM~SB%s~FC~SN)" % (story.story_title[:32], starred_story.user_tags))
    
    return {'code': code, 'message': message, 'starred_count': starred_count, 'starred_counts': starred_counts}
    
@required_params('story_id')
@ajax_login_required
@json.json_view
def mark_story_as_unstarred(request):
    return _mark_story_as_unstarred(request)
    
@required_params('story_hash')
@ajax_login_required
@json.json_view
def mark_story_hash_as_unstarred(request):
    return _mark_story_as_unstarred(request)

def _mark_story_as_unstarred(request):
    code     = 1
    story_id = request.POST.get('story_id', None)
    story_hash = request.REQUEST.get('story_hash', None)
    starred_counts = None
    starred_story = None
    
    if story_id:
        starred_story = MStarredStory.objects(user_id=request.user.pk, story_guid=story_id)
    if not story_id or not starred_story:
        starred_story = MStarredStory.objects(user_id=request.user.pk, story_hash=story_hash or story_id)
    if starred_story:
        starred_story = starred_story[0]
        logging.user(request, "~FCUnstarring: ~SB%s" % (starred_story.story_title[:50]))
        user_tags = starred_story.user_tags
        feed_id = starred_story.story_feed_id
        MActivity.remove_starred_story(user_id=request.user.pk, 
                                       story_feed_id=starred_story.story_feed_id,
                                       story_id=starred_story.story_guid)
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
        # MStarredStoryCounts.schedule_count_tags_for_user(request.user.pk)
        MStarredStoryCounts.count_for_user(request.user.pk, total_only=True)
        starred_counts = MStarredStoryCounts.user_counts(request.user.pk)
    else:
        code = -1
    
    return {'code': code, 'starred_counts': starred_counts}

@ajax_login_required
@json.json_view
def send_story_email(request):
    code       = 1
    message    = 'OK'
    story_id   = request.POST['story_id']
    feed_id    = request.POST['feed_id']
    to_addresses = request.POST.get('to', '').replace(',', ' ').replace('  ', ' ').strip().split(' ')
    from_name  = request.POST['from_name']
    from_email = request.POST['from_email']
    email_cc   = is_true(request.POST.get('email_cc', 'true'))
    comments   = request.POST['comments']
    comments   = comments[:2048] # Separated due to PyLint
    from_address = 'share@newsblur.com'
    share_user_profile = MSocialProfile.get_user(request.user.pk)

    if not to_addresses:
        code = -1
        message = 'Please provide at least one email address.'
    elif not all(email_re.match(to_address) for to_address in to_addresses if to_addresses):
        code = -1
        message = 'You need to send the email to a valid email address.'
    elif not email_re.match(from_email):
        code = -1
        message = 'You need to provide your email address.'
    elif not from_name:
        code = -1
        message = 'You need to provide your name.'
    else:
        story, _ = MStory.find_story(feed_id, story_id)
        story   = Feed.format_story(story, feed_id, text=True)
        feed    = Feed.get_by_id(story['story_feed_id'])
        params  = {
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
        text    = render_to_string('mail/email_story.txt', params)
        html    = render_to_string('mail/email_story.xhtml', params)
        subject = '%s' % (story['story_title'])
        cc      = None
        if email_cc:
            cc = ['%s <%s>' % (from_name, from_email)]
        subject = subject.replace('\n', ' ')
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % from_address,
                                         to=to_addresses, 
                                         cc=cc,
                                         headers={'Reply-To': '%s <%s>' % (from_name, from_email)})
        msg.attach_alternative(html, "text/html")
        try:
            msg.send()
        except boto.ses.connection.ResponseError, e:
            code = -1
            message = "Email error: %s" % str(e)
        logging.user(request, '~BMSharing story by email to %s recipient%s: ~FY~SB%s~SN~BM~FY/~SB%s' % 
                              (len(to_addresses), '' if len(to_addresses) == 1 else 's', 
                               story['story_title'][:50], feed and feed.feed_title[:50]))
        
    return {'code': code, 'message': message}

@json.json_view
def load_tutorial(request):
    if request.REQUEST.get('finished'):
        logging.user(request, '~BY~FW~SBFinishing Tutorial')
        return {}
    else:
        newsblur_feed = Feed.objects.filter(feed_address__icontains='blog.newsblur.com').order_by('-pk')[0]
        logging.user(request, '~BY~FW~SBLoading Tutorial')
        return {
            'newsblur_feed': newsblur_feed.canonical()
        }
