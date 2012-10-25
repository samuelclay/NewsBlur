import datetime
import time
import boto
import redis
from django.shortcuts import get_object_or_404
from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.template.loader import render_to_string
from django.db import IntegrityError
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
from mongoengine.queryset import OperationError
from apps.recommendations.models import RecommendedFeed
from apps.analyzer.models import MClassifierTitle, MClassifierAuthor, MClassifierFeed, MClassifierTag
from apps.analyzer.models import apply_classifier_titles, apply_classifier_feeds
from apps.analyzer.models import apply_classifier_authors, apply_classifier_tags
from apps.analyzer.models import get_classifiers_for_user, sort_classifiers_by_feed
from apps.profile.models import Profile
from apps.reader.models import UserSubscription, UserSubscriptionFolders, MUserStory, Feature
from apps.reader.forms import SignupForm, LoginForm, FeatureForm
from apps.rss_feeds.models import MFeedIcon
from apps.statistics.models import MStatistics
try:
    from apps.rss_feeds.models import Feed, MFeedPage, DuplicateFeed, MStory, MStarredStory
except:
    pass
from apps.social.models import MSharedStory, MSocialProfile, MSocialServices
from apps.social.models import MSocialSubscription, MActivity
from apps.categories.models import MCategory
from apps.social.views import load_social_page
from utils import json_functions as json
from utils.user_functions import get_user, ajax_login_required
from utils.feed_functions import relative_timesince
from utils.story_functions import format_story_link_date__short
from utils.story_functions import format_story_link_date__long
from utils.story_functions import strip_tags
from utils import log as logging
from utils.view_functions import get_argument_or_404, render_to, is_true
from utils.ratelimit import ratelimit
from vendor.timezones.utilities import localtime_for_timezone


@never_cache
@render_to('reader/dashboard.xhtml')
def index(request, **kwargs):
    if request.method == "GET" and request.subdomain and request.subdomain not in ['dev', 'app02', 'app01', 'www']:
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
    active_count      = UserSubscription.objects.filter(user=request.user, active=True).count()
    train_count       = UserSubscription.objects.filter(user=request.user, active=True, is_trained=False,
                                                        feed__stories_last_month__gte=1).count()
    recommended_feeds = RecommendedFeed.objects.filter(is_public=True,
                                                       approved_date__lte=datetime.datetime.now())\
                                                       .select_related('feed')[:2]
    unmoderated_feeds = RecommendedFeed.objects.filter(is_public=False,
                                                       declined_date__isnull=True).select_related('feed')[:2]
    statistics        = MStatistics.all()
    social_profile    = MSocialProfile.get_user(user.pk)

    start_import_from_google_reader = request.session.get('import_from_google_reader', False)
    if start_import_from_google_reader:
        del request.session['import_from_google_reader']
    
    return {
        'user_profile'      : user.profile,
        'feed_count'        : feed_count,
        'active_count'      : active_count,
        'train_count'       : active_count - train_count,
        'account_images'    : range(1, 4),
        'recommended_feeds' : recommended_feeds,
        'unmoderated_feeds' : unmoderated_feeds,
        'statistics'        : statistics,
        'social_profile'    : social_profile,
        'start_import_from_google_reader': start_import_from_google_reader,
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
            logging.user(new_user, "~FG~SB~BBNEW SIGNUP~FW")
            return HttpResponseRedirect(reverse('index'))

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
    
    if next:
        next = '?next=' + next
        
    return HttpResponseRedirect(reverse('index') + next)
    
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
    
    for sub in user_subs:
        pk = sub.feed_id
        if update_counts:
            sub.calculate_feed_scores(silent=True)
        feeds[pk] = sub.canonical(include_favicon=include_favicons)
        if not sub.feed.active and not sub.feed.has_feed_exception and not sub.feed.has_page_exception:
            sub.feed.count_subscribers()
            sub.feed.schedule_feed_fetch_immediately()
        if sub.active and sub.feed.active_subscribers <= 0:
            sub.feed.count_subscribers()
            sub.feed.schedule_feed_fetch_immediately()
            
    starred_count = MStarredStory.objects(user_id=user.pk).count()
    
    social_params = {
        'user_id': user.pk,
        'include_favicon': include_favicons,
        'update_counts': update_counts,
    }
    social_feeds = MSocialSubscription.feeds(**social_params)
    social_profile = MSocialProfile.profile(user.pk)
    social_services = MSocialServices.profile(user.pk)
    
    user.profile.dashboard_date = datetime.datetime.now()
    user.profile.save()
    
    categories = None
    if not user_subs:
        categories = MCategory.serialize()
    
    data = {
        'feeds': feeds.values() if version == 2 else feeds,
        'social_feeds': social_feeds,
        'social_profile': social_profile,
        'social_services': social_services,
        'folders': json.decode(folders.folders),
        'starred_count': starred_count,
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
    flat_folders = {" ": []}
    iphone_version = "1.5"
    
    if include_favicons == 'false': include_favicons = False
    if update_counts == 'false': update_counts = False
    
    if not user.is_authenticated():
        return HttpResponseForbidden()
    
    try:
        folders = UserSubscriptionFolders.objects.get(user=user)
    except UserSubscriptionFolders.DoesNotExist:
        folders = []
        
    user_subs = UserSubscription.objects.select_related('feed').filter(user=user, active=True)

    for sub in user_subs:
        if update_counts and sub.needs_unread_recalc:
            sub.calculate_feed_scores(silent=True)
        feeds[sub.feed_id] = sub.canonical(include_favicon=include_favicons)
    
    if folders:
        folders = json.decode(folders.folders)
    
        def make_feeds_folder(items, parent_folder="", depth=0):
            for item in items:
                if isinstance(item, int) and item in feeds:
                    if not parent_folder:
                        parent_folder = ' '
                    if parent_folder in flat_folders:
                        flat_folders[parent_folder].append(item)
                    else:
                        flat_folders[parent_folder] = [item]
                elif isinstance(item, dict):
                    for folder_name in item:
                        folder = item[folder_name]
                        flat_folder_name = "%s%s%s" % (
                            parent_folder if parent_folder and parent_folder != ' ' else "",
                            " - " if parent_folder and parent_folder != ' ' else "",
                            folder_name
                        )
                        flat_folders[flat_folder_name] = []
                        make_feeds_folder(folder, flat_folder_name, depth+1)
        
        make_feeds_folder(folders)
    
    social_params = {
        'user_id': user.pk,
        'include_favicon': include_favicons,
        'update_counts': update_counts,
    }
    social_feeds = MSocialSubscription.feeds(**social_params)
    social_profile = MSocialProfile.profile(user.pk)
    starred_count = MStarredStory.objects(user_id=user.pk).count()
    
    categories = None
    if not user_subs:
        categories = MCategory.serialize()
        
    logging.user(request, "~FBLoading ~SB%s~SN/~SB%s~SN feeds/socials ~FMflat~FB. %s" % (
            len(feeds.keys()), len(social_feeds), '~SBUpdating counts.' if update_counts else ''))

    data = {
        "flat_folders": flat_folders, 
        "feeds": feeds,
        "social_feeds": social_feeds,
        "social_profile": social_profile,
        "user": user.username,
        "user_profile": user.profile,
        "iphone_version": iphone_version,
        "categories": categories,
        'starred_count': starred_count,
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
    feed_icons = dict([(i.feed_id, i) for i in MFeedIcon.objects(feed_id__in=favicons_fetching)])
    
    for feed_id, feed in feeds.items():
        if feed_id in favicons_fetching and feed_id in feed_icons:
            feeds[feed_id]['favicon'] = feed_icons[feed_id].data
            feeds[feed_id]['favicon_color'] = feed_icons[feed_id].color
            feeds[feed_id]['favicon_fetching'] = feed.get('favicon_fetching')

    user_subs = UserSubscription.objects.select_related('feed').filter(user=user, active=True)
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

    if settings.DEBUG or check_fetch_status:
        logging.user(request, "~FBRefreshing %s feeds (%s/%s)" % (
            len(feeds.keys()), check_fetch_status, len(favicons_fetching)))
        
    return {'feeds': feeds, 'social_feeds': social_feeds}

@never_cache
@json.json_view
def feed_unread_count(request):
    user = get_user(request)
    feed_ids = request.REQUEST.getlist('feed_id')
    social_feed_ids = [feed_id for feed_id in feed_ids if 'social:' in feed_id]
    feed_ids = list(set(feed_ids) - set(social_feed_ids))
    
    feeds = {}
    if feed_ids:
        feeds = UserSubscription.feeds_with_updated_counts(user, feed_ids=feed_ids)

    social_feeds = {}
    if social_feed_ids:
        social_feeds = MSocialSubscription.feeds_with_updated_counts(user, social_feed_ids=social_feed_ids)
    
    if settings.DEBUG:
        if len(feed_ids):
            feed_title = Feed.get_by_id(feed_ids[0]).feed_title
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

    return load_single_feed(request, feed_id)
    
@never_cache
@json.json_view
def load_single_feed(request, feed_id):
    start        = time.time()
    user         = get_user(request)
    offset       = int(request.REQUEST.get('offset', 0))
    limit        = int(request.REQUEST.get('limit', 6))
    page         = int(request.REQUEST.get('page', 1))
    order        = request.REQUEST.get('order', 'newest')
    read_filter  = request.REQUEST.get('read_filter', 'all')
    dupe_feed_id = None
    userstories_db = None
    user_profiles = []
    now = localtime_for_timezone(datetime.datetime.now(), user.profile.timezone)
    if page: offset = limit * (page-1)
    if not feed_id: raise Http404

    feed_address = request.REQUEST.get('feed_address')
    feed = Feed.get_by_id(feed_id, feed_address=feed_address)
    if not feed:
        raise Http404
    
    try:
        usersub = UserSubscription.objects.get(user=user, feed=feed)
    except UserSubscription.DoesNotExist:
        usersub = None
    
    if usersub and (read_filter == 'unread' or order == 'oldest'):
        story_ids = usersub.get_stories(order=order, read_filter=read_filter, offset=offset, limit=limit)
        story_date_order = "%sstory_date" % ('' if order == 'oldest' else '-')
        mstories = MStory.objects(id__in=story_ids).order_by(story_date_order)
        stories = Feed.format_stories(mstories)
    else:
        stories = feed.get_stories(offset, limit)
    
    checkpoint1 = time.time()
    
    try:
        stories, user_profiles = MSharedStory.stories_with_comments_and_profiles(stories, user.pk)
    except redis.ConnectionError:
        logging.user(request, "~BR~FK~SBRedis is unavailable for shared stories.")

    checkpoint2 = time.time()
    
    # Get intelligence classifier for user
    
    classifier_feeds   = list(MClassifierFeed.objects(user_id=user.pk, feed_id=feed_id, social_user_id=0))
    classifier_authors = list(MClassifierAuthor.objects(user_id=user.pk, feed_id=feed_id))
    classifier_titles  = list(MClassifierTitle.objects(user_id=user.pk, feed_id=feed_id))
    classifier_tags    = list(MClassifierTag.objects(user_id=user.pk, feed_id=feed_id))
    classifiers = get_classifiers_for_user(user, feed_id=feed_id, 
                                           classifier_feeds=classifier_feeds, 
                                           classifier_authors=classifier_authors, 
                                           classifier_titles=classifier_titles,
                                           classifier_tags=classifier_tags)
    checkpoint3 = time.time()
    
    userstories = []
    if stories:
        story_ids = [story['id'] for story in stories]
        userstories_db = MUserStory.objects(user_id=user.pk,
                                            feed_id=feed.pk,
                                            story_id__in=story_ids
                                            ).only('story_id').hint([('user_id', 1), ('feed_id', 1), ('story_id', 1)])
        starred_stories = MStarredStory.objects(user_id=user.pk, 
                                                story_feed_id=feed.pk, 
                                                story_guid__in=story_ids).only('story_guid', 'starred_date')
        shared_stories = MSharedStory.objects(user_id=user.pk, 
                                              story_feed_id=feed_id, 
                                              story_guid__in=story_ids)\
                                     .only('story_guid', 'shared_date', 'comments')
        starred_stories = dict([(story.story_guid, story.starred_date) for story in starred_stories])
        shared_stories = dict([(story.story_guid, dict(shared_date=story.shared_date, comments=story.comments))
                               for story in shared_stories])
        userstories = set(us.story_id for us in userstories_db)
            
    checkpoint4 = time.time()
    
    for story in stories:
        story_date = localtime_for_timezone(story['story_date'], user.profile.timezone)
        story['short_parsed_date'] = format_story_link_date__short(story_date, now)
        story['long_parsed_date'] = format_story_link_date__long(story_date, now)
        if usersub:
            if story['id'] in userstories:
                story['read_status'] = 1
            elif not story.get('read_status') and story['story_date'] < usersub.mark_read_date:
                story['read_status'] = 1
            elif not story.get('read_status') and story['story_date'] > usersub.last_read_date:
                story['read_status'] = 0
            if story['id'] in starred_stories:
                story['starred'] = True
                starred_date = localtime_for_timezone(starred_stories[story['id']], user.profile.timezone)
                story['starred_date'] = format_story_link_date__long(starred_date, now)
            if story['id'] in shared_stories:
                story['shared'] = True
                shared_date = localtime_for_timezone(shared_stories[story['id']]['shared_date'], user.profile.timezone)
                story['shared_date'] = format_story_link_date__long(shared_date, now)
                story['shared_comments'] = strip_tags(shared_stories[story['id']]['comments'])
        else:
            story['read_status'] = 1
        story['intelligence'] = {
            'feed': apply_classifier_feeds(classifier_feeds, feed),
            'author': apply_classifier_authors(classifier_authors, story),
            'tags': apply_classifier_tags(classifier_tags, story),
            'title': apply_classifier_titles(classifier_titles, story),
        }
    
    # Intelligence
    feed_tags = json.decode(feed.data.popular_tags) if feed.data.popular_tags else []
    feed_authors = json.decode(feed.data.popular_authors) if feed.data.popular_authors else []
    
    if usersub:
        usersub.feed_opens += 1
        usersub.needs_unread_recalc = True
        usersub.save()
        
    diff1 = checkpoint1-start
    diff2 = checkpoint2-start
    diff3 = checkpoint3-start
    diff4 = checkpoint4-start
    timediff = time.time()-start
    last_update = relative_timesince(feed.last_update)
    time_breakdown = ("~SN~FR(~SB%.4s/%.4s/%.4s/%.4s(%s)~SN)" % (
        diff1, diff2, diff3, diff4, userstories_db and userstories_db.count() or '~SN0~SB')
        if timediff > 0.50 else "")
    logging.user(request, "~FYLoading feed: ~SB%s%s (%s/%s) %s" % (
        feed.feed_title[:22], ('~SN/p%s' % page) if page > 1 else '', order, read_filter, time_breakdown))
    
    data = dict(stories=stories, 
                user_profiles=user_profiles,
                feed_tags=feed_tags, 
                feed_authors=feed_authors, 
                classifiers=classifiers,
                last_update=last_update,
                feed_id=feed.pk,
                elapsed_time=round(float(timediff), 2))
    
    if dupe_feed_id: data['dupe_feed_id'] = dupe_feed_id
    if not usersub:
        data.update(feed.canonical())
    
    return data

def load_feed_page(request, feed_id):
    if not feed_id:
        raise Http404
    
    feed = Feed.get_by_id(feed_id)
    
    if (feed.has_page and 
        not feed.has_page_exception and 
        settings.BACKED_BY_AWS['pages_on_s3'] and 
        feed.s3_page):
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
    
    if not data or not feed.has_page or feed.has_page_exception:
        logging.user(request, "~FYLoading original page, ~FRmissing")
        return render(request, 'static/404_original_page.xhtml', {}, 
            content_type='text/html',
            status=404)
    
    logging.user(request, "~FYLoading original page, from the db")
    return HttpResponse(data, mimetype="text/html; charset=utf-8")
    
@json.json_view
def load_starred_stories(request):
    user   = get_user(request)
    offset = int(request.REQUEST.get('offset', 0))
    limit  = int(request.REQUEST.get('limit', 10))
    page   = int(request.REQUEST.get('page', 0))
    now    = localtime_for_timezone(datetime.datetime.now(), user.profile.timezone)
    if page: offset = limit * (page - 1)
        
    mstories       = MStarredStory.objects(user_id=user.pk).order_by('-starred_date')[offset:offset+limit]
    stories        = Feed.format_stories(mstories)
    story_feed_ids = list(set(s['story_feed_id'] for s in stories))
    usersub_ids    = UserSubscription.objects.filter(user__pk=user.pk, feed__pk__in=story_feed_ids).values('feed__pk')
    usersub_ids    = [us['feed__pk'] for us in usersub_ids]
    unsub_feed_ids = list(set(story_feed_ids).difference(set(usersub_ids)))
    unsub_feeds    = Feed.objects.filter(pk__in=unsub_feed_ids)
    unsub_feeds    = dict((feed.pk, feed.canonical(include_favicon=False)) for feed in unsub_feeds)

    for story in stories:
        story_date                 = localtime_for_timezone(story['story_date'], user.profile.timezone)
        story['short_parsed_date'] = format_story_link_date__short(story_date, now)
        story['long_parsed_date']  = format_story_link_date__long(story_date, now)
        starred_date               = localtime_for_timezone(story['starred_date'], user.profile.timezone)
        story['starred_date']      = format_story_link_date__long(starred_date, now)
        story['read_status']       = 1
        story['starred']           = True
        story['intelligence']      = {
            'feed':   1,
            'author': 0,
            'tags':   0,
            'title':  0,
        }
    
    logging.user(request, "~FCLoading starred stories: ~SB%s stories" % (len(stories)))
    
    return dict(stories=stories, feeds=unsub_feeds)

@json.json_view
def load_river_stories__redis(request):
    limit             = 12
    start             = time.time()
    user              = get_user(request)
    feed_ids          = [int(feed_id) for feed_id in request.REQUEST.getlist('feeds') if feed_id]
    original_feed_ids = list(feed_ids)
    page              = int(request.REQUEST.get('page', 1))
    order             = request.REQUEST.get('order', 'newest')
    read_filter       = request.REQUEST.get('read_filter', 'unread')
    now               = localtime_for_timezone(datetime.datetime.now(), user.profile.timezone)

    if not feed_ids: 
        logging.user(request, "~FCLoading empty river stories: page %s" % (page))
        return dict(stories=[])
    
    offset = (page-1) * limit
    limit = page * limit - 1
    
    story_ids = UserSubscription.feed_stories(user.pk, feed_ids, offset=offset, limit=limit,
                                              order=order, read_filter=read_filter)
    story_date_order = "%sstory_date" % ('' if order == 'oldest' else '-')
    mstories = MStory.objects(id__in=story_ids).order_by(story_date_order)
    stories = Feed.format_stories(mstories)
    found_feed_ids = list(set([story['story_feed_id'] for story in stories]))
    stories, user_profiles = MSharedStory.stories_with_comments_and_profiles(stories, user.pk)
    
    # Find starred stories
    if found_feed_ids:
        starred_stories = MStarredStory.objects(
            user_id=user.pk,
            story_feed_id__in=found_feed_ids
        ).only('story_guid', 'starred_date')
        starred_stories = dict([(story.story_guid, story.starred_date) 
                                for story in starred_stories])
    else:
        starred_stories = {}
    
    # Intelligence classifiers for all feeds involved
    if found_feed_ids:
        classifier_feeds = list(MClassifierFeed.objects(user_id=user.pk,
                                                   feed_id__in=found_feed_ids))
        classifier_authors = list(MClassifierAuthor.objects(user_id=user.pk, 
                                                       feed_id__in=found_feed_ids))
        classifier_titles = list(MClassifierTitle.objects(user_id=user.pk, 
                                                     feed_id__in=found_feed_ids))
        classifier_tags = list(MClassifierTag.objects(user_id=user.pk, 
                                                 feed_id__in=found_feed_ids))
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
    for story in stories:
        story['read_status'] = 0
        story_date = localtime_for_timezone(story['story_date'], user.profile.timezone)
        story['short_parsed_date'] = format_story_link_date__short(story_date, now)
        story['long_parsed_date']  = format_story_link_date__long(story_date, now)
        if story['id'] in starred_stories:
            story['starred'] = True
            starred_date = localtime_for_timezone(starred_stories[story['id']], user.profile.timezone)
            story['starred_date'] = format_story_link_date__long(starred_date, now)
        story['intelligence'] = {
            'feed':   apply_classifier_feeds(classifier_feeds, story['story_feed_id']),
            'author': apply_classifier_authors(classifier_authors, story),
            'tags':   apply_classifier_tags(classifier_tags, story),
            'title':  apply_classifier_titles(classifier_titles, story),
        }

    diff = time.time() - start
    timediff = round(float(diff), 2)
    logging.user(request, "~FYLoading ~FCriver stories~FY: ~SBp%s~SN (%s/%s "
                               "stories, ~SN%s/%s/%s feeds)" % 
                               (page, len(stories), len(mstories), len(found_feed_ids), 
                               len(feed_ids), len(original_feed_ids)))
    
    return dict(stories=stories,
                classifiers=classifiers, 
                elapsed_time=timediff, 
                user_profiles=user_profiles)
    
    
@ajax_login_required
@json.json_view
def mark_all_as_read(request):
    code = 1
    days = int(request.POST.get('days', 0))
    
    feeds = UserSubscription.objects.filter(user=request.user)
    for sub in feeds:
        if days == 0:
            sub.mark_feed_read()
        else:
            read_date = datetime.datetime.utcnow() - datetime.timedelta(days=days)
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
    feed_id = int(get_argument_or_404(request, 'feed_id'))
    
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

    r = redis.Redis(connection_pool=settings.REDIS_POOL)
    r.publish(request.user.username, 'feed:%s' % feed_id)

    return data
    
@ajax_login_required
@json.json_view
def mark_feed_stories_as_read(request):
    r = redis.Redis(connection_pool=settings.REDIS_POOL)
    feeds_stories = request.REQUEST.get('feeds_stories', "{}")
    feeds_stories = json.decode(feeds_stories)
    for feed_id, story_ids in feeds_stories.items():
        feed_id = int(feed_id)
        try:
            usersub = UserSubscription.objects.select_related('feed').get(user=request.user, feed=feed_id)
            data = usersub.mark_story_ids_as_read(story_ids)
        except UserSubscription.DoesNotExist:
            return dict(code=-1, error="You are not subscribed to this feed_id: %d" % feed_id)
        except Feed.DoesNotExist:
            duplicate_feed = DuplicateFeed.objects.filter(duplicate_feed_id=feed_id)
            try:
                if not duplicate_feed: raise Feed.DoesNotExist
                usersub = UserSubscription.objects.get(user=request.user, 
                                                       feed=duplicate_feed[0].feed)
                data = usersub.mark_story_ids_as_read(story_ids)
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
    r = redis.Redis(connection_pool=settings.REDIS_POOL)
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
                code = -1
                errors.append("You are not subscribed to this social user_id: %s" % social_user_id)
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
    
@ajax_login_required
@json.json_view
def mark_story_as_unread(request):
    story_id = request.POST['story_id']
    feed_id = request.POST['feed_id']
    feed_id = int(feed_id)
    
    try:
        usersub = UserSubscription.objects.select_related('feed').get(user=request.user, feed=feed_id)
        feed = usersub.feed
    except UserSubscription.DoesNotExist:
        usersub = None
        feed = Feed.get_by_id(feed_id)
        
    if usersub and not usersub.needs_unread_recalc:
        usersub.needs_unread_recalc = True
        usersub.save()
        
    data = dict(code=0, payload=dict(story_id=story_id))
    
    story, found_original = MStory.find_story(feed_id, story_id)
    
    if usersub and story.story_date < usersub.mark_read_date:
        # Story is outside the mark as read range, so invert all stories before.
        newer_stories = MStory.objects(story_feed_id=story.story_feed_id,
                                       story_date__gte=story.story_date,
                                       story_date__lte=usersub.mark_read_date
                                       ).only('story_guid')
        newer_stories = [s.story_guid for s in newer_stories]
        usersub.mark_read_date = story.story_date - datetime.timedelta(minutes=1)
        usersub.needs_unread_recalc = True
        usersub.save()
        
        # Mark stories as read only after the mark_read_date has been moved, otherwise
        # these would be ignored.
        data = usersub.mark_story_ids_as_read(newer_stories, request=request)
    
    social_subs = MSocialSubscription.mark_dirty_sharing_story(user_id=request.user.pk, 
                                                               story_feed_id=feed_id, 
                                                               story_guid_hash=story.guid_hash)
    dirty_count = social_subs and social_subs.count()
    dirty_count = ("(%s social_subs)" % dirty_count) if dirty_count else ""
    
    try:
        m = MUserStory.objects.get(user_id=request.user.pk, feed_id=feed_id, story_id=story_id)
        m.delete()
    except MUserStory.DoesNotExist:
        logging.user(request, "~BY~SB~FRCouldn't find read story to mark as unread.")

    r = redis.Redis(connection_pool=settings.REDIS_POOL)
    r.publish(request.user.username, 'feed:%s' % feed_id)

    logging.user(request, "~FY~SBUnread~SN story in feed: %s %s" % (feed, dirty_count))
    
    return data
    
@ajax_login_required
@json.json_view
def mark_feed_as_read(request):
    feed_ids = request.REQUEST.getlist('feed_id')
    multiple = len(feed_ids) > 1
    code = 1
    
    for feed_id in feed_ids:
        if 'social:' in feed_id:
            user_id = int(feed_id.replace('social:', ''))
            sub = MSocialSubscription.objects.get(user_id=request.user.pk, subscription_user_id=user_id)
            if not multiple:
                sub_user = User.objects.get(pk=sub.subscription_user_id)
                logging.user(request, "~FMMarking social feed as read: ~SB%s" % (sub_user.username,))
        else:
            try:
                feed = Feed.objects.get(id=feed_id)
                sub = UserSubscription.objects.get(feed=feed, user=request.user)
                if not multiple:
                    logging.user(request, "~FMMarking feed as read: ~SB%s" % (feed,))
            except (Feed.DoesNotExist, UserSubscription.DoesNotExist):
                continue

        if not sub:
            continue
        
        try:
            sub.mark_feed_read()
        except IntegrityError:
            code = -1
            
    if multiple:
        logging.user(request, "~FMMarking ~SB%s~SN feeds as read" % len(feed_ids))
        
    return dict(code=code)

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
    auto_active = is_true(request.POST.get('auto_active', 1))
    skip_fetch = is_true(request.POST.get('skip_fetch', False))
    feed = None
    
    if not url:
        code = -1
        message = 'Enter in the website address or the feed URL.'
    else:
        folder = request.POST.get('folder', '')
        code, message, us = UserSubscription.add_subscription(user=request.user, feed_address=url, 
                                                             folder=folder, auto_active=auto_active,
                                                             skip_fetch=skip_fetch)
        feed = us and us.feed
        
    return dict(code=code, message=message, feed=feed)

@ajax_login_required
@json.json_view
def add_folder(request):
    folder = request.POST['folder']
    parent_folder = request.POST.get('parent_folder', '')

    logging.user(request, "~FRAdding Folder: ~SB%s (in %s)" % (folder, parent_folder))
    
    if folder:
        code = 1
        message = ""
        user_sub_folders_object, _ = UserSubscriptionFolders.objects.get_or_create(user=request.user)
        user_sub_folders_object.add_folder(parent_folder, folder)
    else:
        code = -1
        message = "Gotta write in a folder name."
        
    return dict(code=code, message=message)

@ajax_login_required
@json.json_view
def delete_feed(request):
    feed_id = int(request.POST['feed_id'])
    in_folder = request.POST.get('in_folder', '')
    if in_folder == ' ':
        in_folder = ""
    
    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders.delete_feed(feed_id, in_folder)
    
    feed = Feed.objects.filter(pk=feed_id)
    if feed:
        feed[0].count_subscribers()
    
    return dict(code=1)

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
    in_folder = request.POST.get('in_folder', '')
    feed_ids_in_folder = [int(f) for f in request.REQUEST.getlist('feed_id') if f]
    
    # Works piss poor with duplicate folder titles, if they are both in the same folder.
    # Deletes all, but only in the same folder parent. But nobody should be doing that, right?
    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders.delete_folder(folder_to_delete, in_folder, feed_ids_in_folder)

    return dict(code=1)
    
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
def move_feed_to_folder(request):
    feed_id = int(request.POST['feed_id'])
    in_folder = request.POST.get('in_folder', '')
    to_folder = request.POST.get('to_folder', '')

    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders = user_sub_folders.move_feed_to_folder(feed_id, in_folder=in_folder, to_folder=to_folder)

    return dict(code=1, folders=json.decode(user_sub_folders.folders))
    
@ajax_login_required
@json.json_view
def move_folder_to_folder(request):
    folder_name = request.POST['folder_name']
    in_folder = request.POST.get('in_folder', '')
    to_folder = request.POST.get('to_folder', '')
    
    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders = user_sub_folders.move_folder_to_folder(folder_name, in_folder=in_folder, to_folder=to_folder)

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
    approved_feeds = [int(feed_id) for feed_id in request.POST.getlist('approved_feeds') if feed_id][:64]
    activated = 0
    usersubs = UserSubscription.objects.filter(user=request.user)
    
    for sub in usersubs:
        try:
            if sub.feed_id in approved_feeds:
                activated += 1
                if not sub.active:
                    sub.active = True
                    sub.save()
                    sub.feed.count_subscribers()
            elif sub.active:
                sub.active = False
                sub.save()
        except Feed.DoesNotExist:
            pass
            
    
    logging.user(request, "~BB~FW~SBActivated standard account: ~FC%s~SN/~SB%s" % (
        activated, 
        usersubs.count()
    ))
    request.user.profile.queue_new_feeds()
    request.user.profile.refresh_stale_feeds(exclude_new=True)

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
    
@ajax_login_required
@json.json_view
def mark_story_as_starred(request):
    code     = 1
    feed_id  = int(request.POST['feed_id'])
    story_id = request.POST['story_id']
    
    story = MStory.objects(story_feed_id=feed_id, story_guid=story_id).limit(1)
    if story:
        story_db = dict([(k, v) for k, v in story[0]._data.items() 
                                if k is not None and v is not None])
        now = datetime.datetime.now()
        story_values = dict(user_id=request.user.pk, starred_date=now, **story_db)
        starred_story, created = MStarredStory.objects.get_or_create(
            story_guid=story_values.pop('story_guid'),
            user_id=story_values.pop('user_id'),
            defaults=story_values)
        if created:
            logging.user(request, "~FCStarring: ~SB%s" % (story[0].story_title[:50]))
            MActivity.new_starred_story(user_id=request.user.pk, 
                                        story_title=story[0].story_title, 
                                        story_feed_id=feed_id,
                                        story_id=starred_story.story_guid)
        else:
            logging.user(request, "~FC~BRAlready stared:~SN~FC ~SB%s" % (story[0].story_title[:50]))
    else:
        code = -1
    
    return {'code': code}
    
@ajax_login_required
@json.json_view
def mark_story_as_unstarred(request):
    code     = 1
    story_id = request.POST['story_id']

    starred_story = MStarredStory.objects(user_id=request.user.pk, story_guid=story_id)
    if starred_story:
        logging.user(request, "~FCUnstarring: ~SB%s" % (starred_story[0].story_title[:50]))
        starred_story.delete()
    else:
        code = -1
    
    return {'code': code}

@ajax_login_required
@json.json_view
def send_story_email(request):
    code       = 1
    message    = 'OK'
    story_id   = request.POST['story_id']
    feed_id    = request.POST['feed_id']
    to_addresses = request.POST.get('to', '').replace(',', ' ').replace('  ', ' ').split(' ')
    from_name  = request.POST['from_name']
    from_email = request.POST['from_email']
    comments   = request.POST['comments']
    comments   = comments[:2048] # Separated due to PyLint
    from_address = 'share@newsblur.com'

    if not to_addresses:
        code = -1
        message = 'Please provide at least one email address.'
    elif not all(email_re.match(to_address) for to_address in to_addresses):
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
        feed    = Feed.objects.get(pk=story['story_feed_id'])
        text    = render_to_string('mail/email_story_text.xhtml', locals())
        html    = render_to_string('mail/email_story_html.xhtml', locals())
        subject = "%s is sharing a story with you: \"%s\"" % (from_name, story['story_title'])
        subject = subject.replace('\n', ' ')
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % from_address,
                                         to=to_addresses, 
                                         cc=['%s <%s>' % (from_name, from_email)],
                                         headers={'Reply-To': '%s <%s>' % (from_name, from_email)})
        msg.attach_alternative(html, "text/html")
        try:
            msg.send()
        except boto.ses.connection.ResponseError, e:
            code = -1
            message = "Email error: %s" % str(e)
        logging.user(request, '~BMSharing story by email to %s recipient%s: ~FY~SB%s~SN~BM~FY/~SB%s' % 
                              (len(to_addresses), '' if len(to_addresses) == 1 else 's', 
                               story['story_title'][:50], feed.feed_title[:50]))
        
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
