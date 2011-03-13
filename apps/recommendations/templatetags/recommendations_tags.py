from django import template
from apps.reader.models import UserSubscription
from utils.user_functions import get_user

register = template.Library()

@register.inclusion_tag('recommendations/render_recommended_feed.xhtml', takes_context=True)
def render_recommended_feed(context, recommended_feed):
    user = get_user(context['user'])
    
    usersub = UserSubscription.objects.filter(user=user, feed=recommended_feed.feed)
    
    if recommended_feed.feed:
        return {
            'recommended_feed': recommended_feed,
            'usersub': usersub,
            'user': context['user'],
            'has_next_page': True
        }
    