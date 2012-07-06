from django import template

register = template.Library()

@register.inclusion_tag('social/social_story.xhtml')
def render_social_story(story, has_next_story=False):
    return {
        'story': story,
        'has_next_story': has_next_story
    }

@register.inclusion_tag('social/story_share.xhtml')
def render_story_share(story):
    return {
        'story': story,
    }

@register.inclusion_tag('social/story_comment.xhtml')
def render_story_comment(comment):
    return {
        'comment': comment,
    }

@register.inclusion_tag('mail/email_story_comment.xhtml')
def render_email_comment(comment):
    return {
        'comment': comment,
    }
