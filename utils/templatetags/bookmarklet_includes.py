from django.conf import settings
from django import template

register = template.Library()

@register.simple_tag
def include_bookmarklet_js():
    return settings.JAMMIT.render_code('javascripts', 'bookmarklet')
    
@register.simple_tag
def include_bookmarklet_css():
    return settings.JAMMIT.render_code('stylesheets', 'bookmarklet')
