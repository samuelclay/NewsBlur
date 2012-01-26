import datetime
from django import template
from apps.reader.models import UserSubscription
from utils.user_functions import get_user
from apps.rss_feeds.models import MFeedIcon


register = template.Library()

@register.inclusion_tag('recommendations/render_recommended_feed.xhtml', takes_context=True)
def render_recommended_feed(context, recommended_feeds, unmoderated=False):
    user = get_user(context['user'])
    
    usersub = None
    if context['user'].is_authenticated():
        usersub = UserSubscription.objects.filter(user=user, feed=recommended_feeds[0].feed)
    recommended_feed = recommended_feeds and recommended_feeds[0]
    feed_icon = MFeedIcon.objects(feed_id=recommended_feed.feed_id)
    
    if recommended_feed:
        return {
            'recommended_feed'  : recommended_feed,
            'description'       : recommended_feed.description or recommended_feed.feed.data.feed_tagline,
            'usersub'           : usersub,
            'feed_icon'         : feed_icon and feed_icon[0],
            'user'              : context['user'],
            'has_next_page'     : len(recommended_feeds) > 1,
            'unmoderated'       : unmoderated,
            'today'             : datetime.datetime.now(),
        }
    