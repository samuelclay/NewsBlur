import datetime
from utils import log as logging
from django.shortcuts import get_object_or_404, render_to_response
from django.views.decorators.http import condition
from django.http import HttpResponseForbidden, HttpResponseRedirect, HttpResponse, Http404
from django.db.models import Q
from django.conf import settings
from django.contrib.auth.decorators import login_required
from django.template import RequestContext
# from django.db import IntegrityError
from apps.rss_feeds.models import Feed, merge_feeds
from apps.rss_feeds.models import MFeedFetchHistory, MPageFetchHistory, MFeedPushHistory
from apps.rss_feeds.models import MFeedIcon
from apps.analyzer.models import get_classifiers_for_user
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import MStory
from utils.user_functions import ajax_login_required
from utils import json_functions as json, feedfinder
from utils.feed_functions import relative_timeuntil, relative_timesince
from utils.user_functions import get_user
from utils.view_functions import get_argument_or_404
from utils.view_functions import required_params


@json.json_view
def search_feed(request):
    address = request.REQUEST.get('address')
    offset = int(request.REQUEST.get('offset', 0))
    if not address:
        return dict(code=-1, message="Please provide a URL/address.")
        
    feed = Feed.get_feed_from_url(address, create=False, aggressive=True, offset=offset)
    if feed:
        return feed.canonical()
    else:
        return dict(code=-1, message="No feed found matching that XML or website address.")
    
@json.json_view
def load_single_feed(request, feed_id):
    user = get_user(request)
    feed = get_object_or_404(Feed, pk=feed_id)
    classifiers = get_classifiers_for_user(user, feed_id=feed.pk)

    payload = feed.canonical(full=True)
    payload['classifiers'] = classifiers

    return payload

def feed_favicon_etag(request, feed_id):
    try:
        feed_icon = MFeedIcon.objects.get(feed_id=feed_id)
    except MFeedIcon.DoesNotExist:
        return
    
    return feed_icon.color
    
@condition(etag_func=feed_favicon_etag)
def load_feed_favicon(request, feed_id):
    not_found = False
    try:
        feed_icon = MFeedIcon.objects.get(feed_id=feed_id)
    except MFeedIcon.DoesNotExist:
        not_found = True
        
    if not_found or not feed_icon.data:
        return HttpResponseRedirect(settings.MEDIA_URL + 'img/icons/silk/world.png')
        
    icon_data = feed_icon.data.decode('base64')
    return HttpResponse(icon_data, mimetype='image/png')

@json.json_view
def feed_autocomplete(request):
    query = request.GET.get('term')
    version = int(request.GET.get('v', 1))
    
    if not query:
        return dict(code=-1, message="Specify a search 'term'.")
        
    feeds = []
    for field in ['feed_address', 'feed_title', 'feed_link']:
        if not feeds:
            feeds = Feed.objects.filter(**{
                '%s__icontains' % field: query,
                'num_subscribers__gt': 1,
                'branch_from_feed__isnull': True,
            }).exclude(
                Q(**{'%s__icontains' % field: 'token'}) |
                Q(**{'%s__icontains' % field: 'private'})
            ).only(
                'id',
                'feed_title', 
                'feed_address', 
                'num_subscribers'
            ).select_related("data").order_by('-num_subscribers')[:5]
    
    feeds = [{
        'id': feed.pk,
        'value': feed.feed_address,
        'label': feed.feed_title,
        'tagline': feed.data and feed.data.feed_tagline,
        'num_subscribers': feed.num_subscribers,
    } for feed in feeds]
    
    feed_ids = [f['id'] for f in feeds]
    feed_icons = dict((icon.feed_id, icon) for icon in MFeedIcon.objects.filter(feed_id__in=feed_ids))
    
    for feed in feeds:
        if feed['id'] in feed_icons:
            feed_icon = feed_icons[feed['id']]
            if feed_icon.data:
                feed['favicon_color'] = feed_icon.color
                feed['favicon'] = feed_icon.data

    logging.user(request, "~FGAdd Search: ~SB%s ~SN(%s matches)" % (query, len(feeds),))
    
    if version > 1:
        return {
            'feeds': feeds,
            'term': query,
        }
    else:
        return feeds
    
@json.json_view
def load_feed_statistics(request, feed_id):
    stats = dict()
    feed = get_object_or_404(Feed, pk=feed_id)
    feed.save_feed_story_history_statistics()
    feed.save_classifier_counts()
    
    # Dates of last and next update
    stats['active'] = feed.active
    stats['last_update'] = relative_timesince(feed.last_update)
    if feed.is_push:
        stats['next_update'] = "real-time..."
    else:
        stats['next_update'] = relative_timeuntil(feed.next_scheduled_update)

    # Minutes between updates
    update_interval_minutes, _ = feed.get_next_scheduled_update(force=True, verbose=False)
    if feed.is_push:
        stats['update_interval_minutes'] = 0
    else:
        stats['update_interval_minutes'] = update_interval_minutes
    original_active_premium_subscribers = feed.active_premium_subscribers
    original_premium_subscribers = feed.premium_subscribers
    feed.active_premium_subscribers = max(feed.active_premium_subscribers+1, 1)
    feed.premium_subscribers += 1
    premium_update_interval_minutes, _ = feed.get_next_scheduled_update(force=True, verbose=False)
    feed.active_premium_subscribers = original_active_premium_subscribers
    feed.premium_subscribers = original_premium_subscribers
    if feed.is_push:
        stats['premium_update_interval_minutes'] = 0
    else:
        stats['premium_update_interval_minutes'] = premium_update_interval_minutes
    
    # Stories per month - average and month-by-month breakout
    average_stories_per_month, story_count_history = feed.average_stories_per_month, feed.data.story_count_history
    stats['average_stories_per_month'] = average_stories_per_month
    stats['story_count_history'] = story_count_history and json.decode(story_count_history)
    
    # Subscribers
    stats['subscriber_count'] = feed.num_subscribers
    stats['stories_last_month'] = feed.stories_last_month
    stats['last_load_time'] = feed.last_load_time
    stats['premium_subscribers'] = feed.premium_subscribers
    stats['active_subscribers'] = feed.active_subscribers
    stats['active_premium_subscribers'] = feed.active_premium_subscribers
    
    # Classifier counts
    stats['classifier_counts'] = json.decode(feed.data.feed_classifier_counts)
    
    # Fetch histories
    timezone = request.user.profile.timezone
    stats['feed_fetch_history'] = MFeedFetchHistory.feed_history(feed_id, timezone=timezone)
    stats['page_fetch_history'] = MPageFetchHistory.feed_history(feed_id, timezone=timezone)
    stats['feed_push_history'] = MFeedPushHistory.feed_history(feed_id, timezone=timezone)
    
    logging.user(request, "~FBStatistics: ~SB%s ~FG(%s/%s/%s subs)" % (feed, feed.num_subscribers, feed.active_subscribers, feed.premium_subscribers,))

    return stats

@json.json_view
def load_feed_settings(request, feed_id):
    stats = dict()
    feed = get_object_or_404(Feed, pk=feed_id)
    timezone = request.user.profile.timezone
    
    stats['duplicate_addresses'] = feed.duplicate_addresses.all()
    stats['feed_fetch_history'] = MFeedFetchHistory.feed_history(feed_id, timezone=timezone)
    stats['page_fetch_history'] = MPageFetchHistory.feed_history(feed_id, timezone=timezone)
    
    return stats
    
@json.json_view
def exception_retry(request):
    user = get_user(request)
    feed_id = get_argument_or_404(request, 'feed_id')
    reset_fetch = json.decode(request.POST['reset_fetch'])
    feed = Feed.get_by_id(feed_id)
    original_feed = feed
    
    if not feed:
        raise Http404
    
    feed.next_scheduled_update = datetime.datetime.utcnow()
    feed.has_page_exception = False
    feed.has_feed_exception = False
    feed.active = True
    if reset_fetch:
        logging.user(request, "~FRRefreshing exception feed: ~SB%s" % (feed))
        feed.fetched_once = False
    else:
        logging.user(request, "~FRForcing refreshing feed: ~SB%s" % (feed))
        feed.fetched_once = True
    feed.save()

    feed = feed.update(force=True, compute_scores=False, verbose=True)
    feed = Feed.get_by_id(feed.pk)

    try:
        usersub = UserSubscription.objects.get(user=user, feed=feed)
    except UserSubscription.DoesNotExist:
        usersubs = UserSubscription.objects.filter(user=user, feed=original_feed)
        if usersubs:
            usersub = usersubs[0]
            usersub.switch_feed(feed, original_feed)
        else:
            return {'code': -1}
    usersub.calculate_feed_scores(silent=False)
    
    feeds = {feed.pk: usersub and usersub.canonical(full=True), feed_id: usersub.canonical(full=True)}
    return {'code': 1, 'feeds': feeds}
    
    
@ajax_login_required
@json.json_view
def exception_change_feed_address(request):
    feed_id = request.POST['feed_id']
    feed = get_object_or_404(Feed, pk=feed_id)
    original_feed = feed
    feed_address = request.POST['feed_address']
    timezone = request.user.profile.timezone
    code = -1

    if feed.has_page_exception or feed.has_feed_exception:
        # Fix broken feed
        logging.user(request, "~FRFixing feed exception by address: ~SB%s~SN to ~SB%s" % (feed.feed_address, feed_address))
        feed.has_feed_exception = False
        feed.active = True
        feed.fetched_once = False
        feed.feed_address = feed_address
        feed.next_scheduled_update = datetime.datetime.utcnow()
        duplicate_feed = feed.save()
        code = 1
        if duplicate_feed:
            new_feed = Feed.objects.get(pk=duplicate_feed.pk)
            feed = new_feed
            new_feed.next_scheduled_update = datetime.datetime.utcnow()
            new_feed.has_feed_exception = False
            new_feed.active = True
            new_feed.save()
            merge_feeds(new_feed.pk, feed.pk)
    else:
        # Branch good feed
        logging.user(request, "~FRBranching feed by address: ~SB%s~SN to ~SB%s" % (feed.feed_address, feed_address))
        feed, _ = Feed.objects.get_or_create(feed_address=feed_address, feed_link=feed.feed_link)
        code = 1
        if feed.pk != original_feed.pk:
            try:
                feed.branch_from_feed = original_feed.branch_from_feed or original_feed
            except Feed.DoesNotExist:
                feed.branch_from_feed = original_feed
            feed.feed_address_locked = True
            feed.save()

    feed = feed.update()
    feed = Feed.get_by_id(feed.pk)
    try:
        usersub = UserSubscription.objects.get(user=request.user, feed=feed)
    except UserSubscription.DoesNotExist:
        usersubs = UserSubscription.objects.filter(user=request.user, feed=original_feed)
        if usersubs:
            usersub = usersubs[0]
            usersub.switch_feed(feed, original_feed)
        else:
            return {
                'code': -1,
                'feed_fetch_history': MFeedFetchHistory.feed_history(feed_id, timezone=timezone),
                'page_fetch_history': MPageFetchHistory.feed_history(feed_id, timezone=timezone),
            }

    usersub.calculate_feed_scores(silent=False)
    
    feed.update_all_statistics()
    classifiers = get_classifiers_for_user(usersub.user, feed_id=usersub.feed_id)
    
    feeds = {
        original_feed.pk: usersub and usersub.canonical(full=True, classifiers=classifiers), 
    }
    
    if feed and feed.has_feed_exception:
        code = -1
        
    return {
        'code': code, 
        'feeds': feeds, 
        'new_feed_id': usersub.feed_id,
        'feed_fetch_history': MFeedFetchHistory.feed_history(feed_id, timezone=timezone),
        'page_fetch_history': MPageFetchHistory.feed_history(feed_id, timezone=timezone),
    }
    
@ajax_login_required
@json.json_view
def exception_change_feed_link(request):
    feed_id = request.POST['feed_id']
    feed = get_object_or_404(Feed, pk=feed_id)
    original_feed = feed
    feed_link = request.POST['feed_link']
    timezone = request.user.profile.timezone
    code = -1
    
    if feed.has_page_exception or feed.has_feed_exception:
        # Fix broken feed
        logging.user(request, "~FRFixing feed exception by link: ~SB%s~SN to ~SB%s" % (feed.feed_link, feed_link))
        feed_address = feedfinder.feed(feed_link)
        if feed_address:
            code = 1
            feed.has_page_exception = False
            feed.active = True
            feed.fetched_once = False
            feed.feed_link = feed_link
            feed.feed_address = feed_address
            feed.next_scheduled_update = datetime.datetime.utcnow()
            duplicate_feed = feed.save()
            if duplicate_feed:
                new_feed = Feed.objects.get(pk=duplicate_feed.pk)
                feed = new_feed
                new_feed.next_scheduled_update = datetime.datetime.utcnow()
                new_feed.has_page_exception = False
                new_feed.active = True
                new_feed.save()
    else:
        # Branch good feed
        logging.user(request, "~FRBranching feed by link: ~SB%s~SN to ~SB%s" % (feed.feed_link, feed_link))
        feed, _ = Feed.objects.get_or_create(feed_address=feed.feed_address, feed_link=feed_link)
        code = 1
        if feed.pk != original_feed.pk:
            try:
                feed.branch_from_feed = original_feed.branch_from_feed or original_feed
            except Feed.DoesNotExist:
                feed.branch_from_feed = original_feed
            feed.feed_link_locked = True
            feed.save()

    feed = feed.update()
    feed = Feed.get_by_id(feed.pk)

    try:
        usersub = UserSubscription.objects.get(user=request.user, feed=feed)
    except UserSubscription.DoesNotExist:
        usersubs = UserSubscription.objects.filter(user=request.user, feed=original_feed)
        if usersubs:
            usersub = usersubs[0]
            usersub.switch_feed(feed, original_feed)
        else:
            return {
                'code': -1,
                'feed_fetch_history': MFeedFetchHistory.feed_history(feed_id, timezone=timezone),
                'page_fetch_history': MPageFetchHistory.feed_history(feed_id, timezone=timezone),
            }
        
    usersub.calculate_feed_scores(silent=False)
    
    feed.update_all_statistics()
    classifiers = get_classifiers_for_user(usersub.user, feed_id=usersub.feed_id)
    
    if feed and feed.has_feed_exception:
        code = -1
    
    feeds = {
        original_feed.pk: usersub.canonical(full=True, classifiers=classifiers), 
    }
    return {
        'code': code, 
        'feeds': feeds, 
        'new_feed_id': usersub.feed_id,
        'feed_fetch_history': MFeedFetchHistory.feed_history(feed_id, timezone=timezone),
        'page_fetch_history': MPageFetchHistory.feed_history(feed_id, timezone=timezone),
    }

@login_required
def status(request):
    if not request.user.is_staff:
        logging.user(request, "~SKNON-STAFF VIEWING RSS FEEDS STATUS!")
        assert False
        return HttpResponseForbidden()
    minutes  = int(request.GET.get('minutes', 10))
    now      = datetime.datetime.now()
    hour_ago = now - datetime.timedelta(minutes=minutes)
    feeds    = Feed.objects.filter(last_update__gte=hour_ago).order_by('-last_update')
    return render_to_response('rss_feeds/status.xhtml', {
        'feeds': feeds
    }, context_instance=RequestContext(request))

@required_params('story_id', feed_id=int)
@json.json_view
def original_text(request):
    story_id = request.GET['story_id']
    feed_id = request.GET['feed_id']
    force = request.GET.get('force', False)
    
    story, _ = MStory.find_story(story_id=story_id, story_feed_id=feed_id)

    if not story:
        logging.user(request, "~FYFetching ~FGoriginal~FY story text: ~FRstory not found")
        return {'code': -1, 'message': 'Story not found.'}
    
    original_text = story.fetch_original_text(force=force, request=request)
    
    return {
        'feed_id': feed_id,
        'story_id': story_id,
        'original_text': original_text,
    }