from django import template
from apps.reader.models import UserSubscription
from utils.user_functions import get_user

register = template.Library()

@register.inclusion_tag('recommendations/render_recommended_feed.xhtml', takes_context=True)
def render_recommended_feed(context, recommended_feeds):
    user = get_user(context['user'])
    
    usersub = None
    if context['user'].is_authenticated():
        usersub = UserSubscription.objects.filter(user=user, feed=recommended_feeds[0].feed)
    recommended_feed = recommended_feeds and recommended_feeds[0]
    
    if recommended_feed:
        return {
            'recommended_feed': recommended_feed,
            'description': recommended_feed.description or recommended_feed.feed.data.feed_tagline,
            'usersub': usersub,
            'user': context['user'],
            'has_next_page': len(recommended_feeds) > 1
        }
    