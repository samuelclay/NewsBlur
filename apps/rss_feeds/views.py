from utils import log as logging
from django.shortcuts import get_object_or_404
from apps.rss_feeds.models import Feed
from utils import json
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