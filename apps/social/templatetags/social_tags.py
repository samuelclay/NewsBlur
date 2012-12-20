from django import template
from django.conf import settings
from apps.social.models import MSocialProfile

register = template.Library()

@register.inclusion_tag('social/social_story.xhtml', takes_context=True)
def render_social_story(context, story, has_next_story=False):
    user = context['user']
    user_social_profile = context['user_social_profile']
    
    return {
        'story': story,
        'has_next_story': has_next_story,
        'user': user,
        'user_social_profile': user_social_profile,
    }

@register.inclusion_tag('social/story_share.xhtml', takes_context=True)
def render_story_share(context, story):
    user = context['user']
    return {
        'user': user,
        'story': story,
    }
    
@register.inclusion_tag('social/story_comments.xhtml', takes_context=True)
def render_story_comments(context, story):
    user = context['user']
    user_social_profile = context.get('user_social_profile')
    MEDIA_URL = settings.MEDIA_URL
    if not user_social_profile and user.is_authenticated():
        user_social_profile = MSocialProfile.objects.get(user_id=user.pk)
    
    return {
        'user': user,
        'user_social_profile': user_social_profile,
        'story': story,
        'MEDIA_URL': MEDIA_URL,
    }

@register.inclusion_tag('social/story_comment.xhtml', takes_context=True)
def render_story_comment(context, story, comment):
    user = context['user']
    MEDIA_URL = settings.MEDIA_URL
    
    return {
        'user': user,
        'story': story,
        'comment': comment,
        'MEDIA_URL': MEDIA_URL,
    }

@register.inclusion_tag('mail/email_story_comment.xhtml')
def render_email_comment(comment):
    return {
        'comment': comment,
    }
    
@register.inclusion_tag('social/avatars.xhtml')
def render_avatars(avatars):
    if not isinstance(avatars, list):
        avatars = [avatars]
    return {
        'users': avatars,
    }
