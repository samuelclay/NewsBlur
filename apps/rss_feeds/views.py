import datetime
from urlparse import urlparse
from utils import log as logging
from django.shortcuts import get_object_or_404, render_to_response
from django.views.decorators.http import condition
from django.http import HttpResponseForbidden, HttpResponseRedirect, HttpResponse, Http404
from django.conf import settings
from django.contrib.auth.decorators import login_required
from django.template import RequestContext
# from django.db import IntegrityError
from apps.rss_feeds.models import Feed, merge_feeds
from apps.rss_feeds.models import MFetchHistory
from apps.rss_feeds.models import MFeedIcon
from apps.push.models import PushSubscription
from apps.analyzer.models import get_classifiers_for_user
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import MStory
from utils.user_functions import ajax_login_required
from utils import json_functions as json, feedfinder2 as feedfinder
from utils.feed_functions import relative_timeuntil, relative_timesince
from utils.user_functions import get_user
from utils.view_functions import get_argument_or_404
from utils.view_functions import required_params
from utils.view_functions import is_true
from vendor.timezones.utilities import localtime_for_timezone
from utils.ratelimit import ratelimit

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
    address = request.REQUEST.get('address')
    offset = int(request.REQUEST.get('offset', 0))
    if not address:
        return dict(code=-1, message="Please provide a URL/address.")
    
    logging.user(request.user, "~FBFinding feed (search_feed): %s" % address)
    ip = request.META.get('HTTP_X_FORWARDED_FOR', None) or request.META['REMOTE_ADDR']
    logging.user(request.user, "~FBIP: %s" % ip)
    aggressive = request.user.is_authenticated()
    feed = Feed.get_feed_from_url(address, create=False, aggressive=aggressive, offset=offset)
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
        return HttpResponseRedirect(settings.MEDIA_URL + 'img/icons/circular/world.png')
        
    icon_data = feed_icon.data.decode('base64')
    return HttpResponse(icon_data, mimetype='image/png')

@json.json_view
def feed_autocomplete(request):
    query = request.GET.get('term') or request.GET.get('query')
    version = int(request.GET.get('v', 1))
    format = request.GET.get('format', 'autocomplete')
    
    # user = get_user(request)
    # if True or not user.profile.is_premium:
    #     return dict(code=-1, message="Overloaded, no autocomplete results.", feeds=[], term=query)
    
    if not query:
        return dict(code=-1, message="Specify a search 'term'.", feeds=[], term=query)
    
    if '.' in query:
        try:
            parts = urlparse(query)
            if not parts.hostname and not query.startswith('http'):
                parts = urlparse('http://%s' % query)
            if parts.hostname:
                query = [parts.hostname]
                query.extend([p for p in parts.path.split('/') if p])
                query = ' '.join(query)
        except:
            logging.user(request, "~FGAdd search, could not parse url in ~FR%s" % query)
    
    query_params = query.split(' ')
    tries_left = 5
    while len(query_params) and tries_left:
        tries_left -= 1
        feed_ids = Feed.autocomplete(' '.join(query_params))
        if feed_ids:
            break
        else:
            query_params = query_params[:-1]
    
    feeds = list(set([Feed.get_by_id(feed_id) for feed_id in feed_ids]))
    feeds = [feed for feed in feeds if feed and not feed.branch_from_feed]
    feeds = [feed for feed in feeds if all([x not in feed.feed_address for x in IGNORE_AUTOCOMPLETE])]
    
    if format == 'autocomplete':
        feeds = [{
            'id': feed.pk,
            'value': feed.feed_address,
            'label': feed.feed_title,
            'tagline': feed.data and feed.data.feed_tagline,
            'num_subscribers': feed.num_subscribers,
        } for feed in feeds]
    else:
        feeds = [feed.canonical(full=True) for feed in feeds]
    feeds = sorted(feeds, key=lambda f: -1 * f['num_subscribers'])
    
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
    
@ratelimit(minutes=1, requests=30)
@json.json_view
def load_feed_statistics(request, feed_id):
    user = get_user(request)
    timezone = user.profile.timezone
    stats = dict()
    feed = get_object_or_404(Feed, pk=feed_id)
    feed.update_all_statistics()
    feed.set_next_scheduled_update(verbose=True, skip_scheduling=True)
    feed.save_feed_story_history_statistics()
    feed.save_classifier_counts()
    
    # Dates of last and next update
    stats['active'] = feed.active
    stats['last_update'] = relative_timesince(feed.last_update)
    stats['next_update'] = relative_timeuntil(feed.next_scheduled_update)
    stats['push'] = feed.is_push
    if feed.is_push:
        try:
            stats['push_expires'] = localtime_for_timezone(feed.push.lease_expires, 
                                                           timezone).strftime("%Y-%m-%d %H:%M:%S")
        except PushSubscription.DoesNotExist:
            stats['push_expires'] = 'Missing push'
            feed.is_push = False
            feed.save()

    # Minutes between updates
    update_interval_minutes = feed.get_next_scheduled_update(force=True, verbose=False)
    stats['update_interval_minutes'] = update_interval_minutes
    original_active_premium_subscribers = feed.active_premium_subscribers
    original_premium_subscribers = feed.premium_subscribers
    feed.active_premium_subscribers = max(feed.active_premium_subscribers+1, 1)
    feed.premium_subscribers += 1
    premium_update_interval_minutes = feed.get_next_scheduled_update(force=True, verbose=False,
                                                                     premium_speed=True)
    feed.active_premium_subscribers = original_active_premium_subscribers
    feed.premium_subscribers = original_premium_subscribers
    stats['premium_update_interval_minutes'] = premium_update_interval_minutes
    stats['errors_since_good'] = feed.errors_since_good
    
    # Stories per month - average and month-by-month breakout
    average_stories_per_month, story_count_history = feed.average_stories_per_month, feed.data.story_count_history
    stats['average_stories_per_month'] = average_stories_per_month
    story_count_history = story_count_history and json.decode(story_count_history)
    if story_count_history and isinstance(story_count_history, dict):
        stats['story_count_history'] = story_count_history['months']
        stats['story_days_history'] = story_count_history['days']
        stats['story_hours_history'] = story_count_history['hours']
    else:
        stats['story_count_history'] = story_count_history
    
    # Rotate hours to match user's timezone offset
    localoffset = timezone.utcoffset(datetime.datetime.utcnow())
    hours_offset = int(localoffset.total_seconds() / 3600)
    rotated_hours = {}
    for hour, value in stats['story_hours_history'].items():
        rotated_hours[str(int(hour)+hours_offset)] = value
    stats['story_hours_history'] = rotated_hours
    
    # Subscribers
    stats['subscriber_count'] = feed.num_subscribers
    stats['num_subscribers'] = feed.num_subscribers
    stats['stories_last_month'] = feed.stories_last_month
    stats['last_load_time'] = feed.last_load_time
    stats['premium_subscribers'] = feed.premium_subscribers
    stats['active_subscribers'] = feed.active_subscribers
    stats['active_premium_subscribers'] = feed.active_premium_subscribers

    # Classifier counts
    stats['classifier_counts'] = json.decode(feed.data.feed_classifier_counts)
    
    # Fetch histories
    fetch_history = MFetchHistory.feed(feed_id, timezone=timezone)
    stats['feed_fetch_history'] = fetch_history['feed_fetch_history']
    stats['page_fetch_history'] = fetch_history['page_fetch_history']
    stats['feed_push_history'] = fetch_history['push_history']
    
    logging.user(request, "~FBStatistics: ~SB%s" % (feed))

    return stats

@json.json_view
def load_feed_settings(request, feed_id):
    stats = dict()
    feed = get_object_or_404(Feed, pk=feed_id)
    user = get_user(request)
    timezone = user.profile.timezone

    fetch_history = MFetchHistory.feed(feed_id, timezone=timezone)
    stats['feed_fetch_history'] = fetch_history['feed_fetch_history']
    stats['page_fetch_history'] = fetch_history['page_fetch_history']
    stats['feed_push_history'] = fetch_history['push_history']
    stats['duplicate_addresses'] = feed.duplicate_addresses.all()
    
    return stats

@ratelimit(minutes=10, requests=10)
@json.json_view
def exception_retry(request):
    user = get_user(request)
    feed_id = get_argument_or_404(request, 'feed_id')
    reset_fetch = json.decode(request.POST['reset_fetch'])
    feed = Feed.get_by_id(feed_id)
    original_feed = feed
    
    if not feed:
        raise Http404
    
    feed.schedule_feed_fetch_immediately()
    changed = False
    if feed.has_page_exception:
        changed = True
        feed.has_page_exception = False
    if feed.has_feed_exception:
        changed = True
        feed.has_feed_exception = False
    if not feed.active:
        changed = True
        feed.active = True
    if changed:
        feed.save(update_fields=['has_page_exception', 'has_feed_exception', 'active'])
    
    original_fetched_once = feed.fetched_once
    if reset_fetch:
        logging.user(request, "~FRRefreshing exception feed: ~SB%s" % (feed))
        feed.fetched_once = False
    else:
        logging.user(request, "~FRForcing refreshing feed: ~SB%s" % (feed))
        
        feed.fetched_once = True
    if feed.fetched_once != original_fetched_once:
        feed.save(update_fields=['fetched_once'])

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

    if False and (feed.has_page_exception or feed.has_feed_exception):
        # Fix broken feed
        logging.user(request, "~FRFixing feed exception by address: %s - ~SB%s~SN to ~SB%s" % (feed, feed.feed_address, feed_address))
        feed.has_feed_exception = False
        feed.active = True
        feed.fetched_once = False
        feed.feed_address = feed_address
        duplicate_feed = feed.schedule_feed_fetch_immediately()
        code = 1
        if duplicate_feed:
            new_feed = Feed.objects.get(pk=duplicate_feed.pk)
            feed = new_feed
            new_feed.schedule_feed_fetch_immediately()
            new_feed.has_feed_exception = False
            new_feed.active = True
            new_feed = new_feed.save()
            if new_feed.pk != feed.pk:
                merge_feeds(new_feed.pk, feed.pk)
    else:
        # Branch good feed
        logging.user(request, "~FRBranching feed by address: ~SB%s~SN to ~SB%s" % (feed.feed_address, feed_address))
        try:
            feed = Feed.objects.get(hash_address_and_link=Feed.generate_hash_address_and_link(feed_address, feed.feed_link))
        except Feed.DoesNotExist:
            feed = Feed.objects.create(feed_address=feed_address, feed_link=feed.feed_link)
        code = 1
        if feed.pk != original_feed.pk:
            try:
                feed.branch_from_feed = original_feed.branch_from_feed or original_feed
            except Feed.DoesNotExist:
                feed.branch_from_feed = original_feed
            feed.feed_address_locked = True
            feed = feed.save()

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
            fetch_history = MFetchHistory.feed(feed_id, timezone=timezone)
            return {
                'code': -1,
                'feed_fetch_history': fetch_history['feed_fetch_history'],
                'page_fetch_history': fetch_history['page_fetch_history'],
                'push_history': fetch_history['push_history'],
            }

    usersub.calculate_feed_scores(silent=False)
    
    feed.update_all_statistics()
    classifiers = get_classifiers_for_user(usersub.user, feed_id=usersub.feed_id)
    
    feeds = {
        original_feed.pk: usersub and usersub.canonical(full=True, classifiers=classifiers), 
    }
    
    if feed and feed.has_feed_exception:
        code = -1

    fetch_history = MFetchHistory.feed(feed_id, timezone=timezone)
    return {
        'code': code, 
        'feeds': feeds, 
        'new_feed_id': usersub.feed_id,
        'feed_fetch_history': fetch_history['feed_fetch_history'],
        'page_fetch_history': fetch_history['page_fetch_history'],
        'push_history': fetch_history['push_history'],
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
    
    if False and (feed.has_page_exception or feed.has_feed_exception):
        # Fix broken feed
        logging.user(request, "~FRFixing feed exception by link: ~SB%s~SN to ~SB%s" % (feed.feed_link, feed_link))
        found_feed_urls = feedfinder.find_feeds(feed_link)
        if len(found_feed_urls):
            code = 1
            feed.has_page_exception = False
            feed.active = True
            feed.fetched_once = False
            feed.feed_link = feed_link
            feed.feed_address = found_feed_urls[0]
            duplicate_feed = feed.schedule_feed_fetch_immediately()
            if duplicate_feed:
                new_feed = Feed.objects.get(pk=duplicate_feed.pk)
                feed = new_feed
                new_feed.schedule_feed_fetch_immediately()
                new_feed.has_page_exception = False
                new_feed.active = True
                new_feed.save()
    else:
        # Branch good feed
        logging.user(request, "~FRBranching feed by link: ~SB%s~SN to ~SB%s" % (feed.feed_link, feed_link))
        try:
            feed = Feed.objects.get(hash_address_and_link=Feed.generate_hash_address_and_link(feed.feed_address, feed_link))
        except Feed.DoesNotExist:
            feed = Feed.objects.create(feed_address=feed.feed_address, feed_link=feed_link)
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
            fetch_history = MFetchHistory.feed(feed_id, timezone=timezone)
            return {
                'code': -1,
                'feed_fetch_history': fetch_history['feed_fetch_history'],
                'page_fetch_history': fetch_history['page_fetch_history'],
                'push_history': fetch_history['push_history'],
            }
        
    usersub.calculate_feed_scores(silent=False)
    
    feed.update_all_statistics()
    classifiers = get_classifiers_for_user(usersub.user, feed_id=usersub.feed_id)
    
    if feed and feed.has_feed_exception:
        code = -1
    
    feeds = {
        original_feed.pk: usersub.canonical(full=True, classifiers=classifiers), 
    }
    fetch_history = MFetchHistory.feed(feed_id, timezone=timezone)
    return {
        'code': code, 
        'feeds': feeds, 
        'new_feed_id': usersub.feed_id,
        'feed_fetch_history': fetch_history['feed_fetch_history'],
        'page_fetch_history': fetch_history['page_fetch_history'],
        'push_history': fetch_history['push_history'],
    }

@login_required
def status(request):
    if not request.user.is_staff:
        logging.user(request, "~SKNON-STAFF VIEWING RSS FEEDS STATUS!")
        assert False
        return HttpResponseForbidden()
    minutes  = int(request.GET.get('minutes', 1))
    now      = datetime.datetime.now()
    hour_ago = now - datetime.timedelta(minutes=minutes)
    feeds    = Feed.objects.filter(last_update__gte=hour_ago).order_by('-last_update')
    return render_to_response('rss_feeds/status.xhtml', {
        'feeds': feeds
    }, context_instance=RequestContext(request))

@required_params('story_id', feed_id=int)
@json.json_view
def original_text(request):
    story_id = request.REQUEST.get('story_id')
    feed_id = request.REQUEST.get('feed_id')
    story_hash = request.REQUEST.get('story_hash', None)
    force = request.REQUEST.get('force', False)
    debug = request.REQUEST.get('debug', False)

    if story_hash:
        story, _ = MStory.find_story(story_hash=story_hash)
    else:
        story, _ = MStory.find_story(story_id=story_id, story_feed_id=feed_id)

    if not story:
        logging.user(request, "~FYFetching ~FGoriginal~FY story text: ~FRstory not found")
        return {'code': -1, 'message': 'Story not found.', 'original_text': None, 'failed': True}
    
    original_text = story.fetch_original_text(force=force, request=request, debug=debug)

    return {
        'feed_id': feed_id,
        'story_id': story_id,
        'original_text': original_text,
        'failed': not original_text or len(original_text) < 100,
    }

@required_params('story_hash')
def original_story(request):
    story_hash = request.REQUEST.get('story_hash')
    force = request.REQUEST.get('force', False)
    debug = request.REQUEST.get('debug', False)

    story, _ = MStory.find_story(story_hash=story_hash)

    if not story:
        logging.user(request, "~FYFetching ~FGoriginal~FY story page: ~FRstory not found")
        return {'code': -1, 'message': 'Story not found.', 'original_page': None, 'failed': True}
    
    original_page = story.fetch_original_page(force=force, request=request, debug=debug)

    return HttpResponse(original_page or "")

@required_params('story_hash')
@json.json_view
def story_changes(request):
    story_hash = request.REQUEST.get('story_hash', None)
    show_changes = is_true(request.REQUEST.get('show_changes', True))
    story, _ = MStory.find_story(story_hash=story_hash)
    if not story:
        logging.user(request, "~FYFetching ~FGoriginal~FY story page: ~FRstory not found")
        return {'code': -1, 'message': 'Story not found.', 'original_page': None, 'failed': True}
    
    return {
        'story': Feed.format_story(story, show_changes=show_changes)
    }
    