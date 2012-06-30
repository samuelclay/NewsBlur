from django import template

register = template.Library()

@register.inclusion_tag('social/story_share.xhtml')
def render_story_share(story):
    return {
        'story': story,
    }

@register.inclusion_tag('social/story_comments.xhtml')
def render_story_comments(story):
    return {
        'story': story,
    }
