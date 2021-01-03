from django.conf import settings
from django import template
from django.utils.safestring import mark_safe

register = template.Library()

@register.simple_tag
def include_bookmarklet_js():
    return mark_safe(settings.JAMMIT.render_code('javascripts', 'bookmarklet'))
    
@register.simple_tag
def include_bookmarklet_css():
    return mark_safe(settings.JAMMIT.render_code('stylesheets', 'bookmarklet'))
