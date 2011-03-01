from django import template

register = template.Library()

@register.inclusion_tag('recommendations/render_recommended_feed.xhtml', takes_context=True)
def render_recommended_feed(context, recommended_feed):
    return {
        'recommended_feed': recommended_feed,
        'user': context['user'],
    }