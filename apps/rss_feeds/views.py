from utils import log as logging
from django.shortcuts import get_object_or_404
from django.http import HttpResponseForbidden
from apps.rss_feeds.models import Feed, merge_feeds
from utils.user_functions import ajax_login_required
from utils import json, feedfinder
from utils.feed_functions import relative_timeuntil, relative_timesince

@json.json_view
def load_feed_statistics(request):
    stats = dict()
    feed_id = request.GET['feed_id']
    feed = get_object_or_404(Feed, pk=feed_id)
    
    # Dates of last and next update
    stats['last_update'] = relative_timesince(feed.last_update)
    stats['next_update'] = relative_timeuntil(feed.next_scheduled_update)
    
    # Minutes between updates
    update_interval_minutes, random_factor = feed.get_next_scheduled_update()
    stats['update_interval_minutes'] = update_interval_minutes
    
    # Stories per month - average and month-by-month breakout
    average_stories_per_month, story_count_history = feed.average_stories_per_month, feed.story_count_history
    stats['average_stories_per_month'] = average_stories_per_month
    stats['story_count_history'] = story_count_history and json.decode(story_count_history)
    
    # Subscribers
    stats['subscriber_count'] = feed.num_subscribers
    
    logging.info(" ---> [%s] Statistics: %s" % (request.user, feed))
    
    return stats
    
@ajax_login_required
@json.json_view
def exception_retry(request):
    feed_id = request.POST['feed_id']
    feed = get_object_or_404(Feed, pk=feed_id)
    
    feed.has_exception = False
    feed.fetched_once = False
    feed.save()
    
    return {'code': 1}
    
    
@ajax_login_required
@json.json_view
def exception_change_feed_address(request):
    feed_id = request.POST['feed_id']
    feed = get_object_or_404(Feed, pk=feed_id)
    feed_address = request.POST['feed_address']
    
    if not feed.has_exception:
        logging.info(" ***********> [%s] Incorrect feed address change: %s" % (request.user, feed))
        return HttpResponseForbidden()
        
    feed.has_exception = False
    feed.active = True
    feed.fetched_once = False
    feed.feed_address = feed_address
    try:
        feed.save()
    except:
        original_feed = Feed.objects.get(feed_address=feed_address)
        original_feed.has_exception = False
        original_feed.active = True
        original_feed.save()
        merge_feeds(original_feed.pk, feed.pk)
    
    return {'code': 1}
    
@ajax_login_required
@json.json_view
def exception_change_feed_link(request):
    feed_id = request.POST['feed_id']
    feed = get_object_or_404(Feed, pk=feed_id)
    feed_link = request.POST['feed_link']
    code = -1
    
    if not feed.has_exception:
        logging.info(" ***********> [%s] Incorrect feed address change: %s" % (request.user, feed))
        # This Forbidden-403 throws an error, which sounds pretty good to me right now
        return HttpResponseForbidden()
    
    feed_address = feedfinder.feed(feed_link)
    if feed_address:
        code = 1
        feed.has_exception = False
        feed.active = True
        feed.fetched_once = False
        feed.feed_link = feed_link
        feed.feed_address = feed_address
        try:
            feed.save()
        except:
            original_feed = Feed.objects.get(feed_address=feed_address)
            original_feed.has_exception = False
            original_feed.active = True
            original_feed.save()
            merge_feeds(original_feed.pk, feed.pk)
    
    return {'code': code}
    
    