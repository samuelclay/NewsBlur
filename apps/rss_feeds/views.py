from django.shortcuts import get_object_or_404
from apps.rss_feeds.models import Feed
from utils import json
from utils.feed_functions import format_relative_date

@json.json_view
def load_feed_statistics(request):
    stats = dict()
    feed_id = request.GET['feed_id']
    feed = get_object_or_404(Feed, pk=feed_id)
    
    # Dates of last and next update
    stats['last_update'] = format_relative_date(feed.last_update)
    stats['next_update'] = format_relative_date(feed.next_scheduled_update, future=True)
    
    # Minutes between updates
    update_interval_minutes, random_factor = feed.get_next_scheduled_update()
    stats['update_interval_minutes'] = update_interval_minutes
    
    # Stories per month - average and month-by-month breakout
    average_stories_per_month, stories_last_year = feed.average_stories_per_month, feed.stories_last_year
    stats['average_stories_per_month'] = average_stories_per_month
    stats['stories_last_year'] = stories_last_year and json.decode(stories_last_year)
    
    # Subscribers
    stats['subscriber_count'] = feed.num_subscribers
    
    return stats