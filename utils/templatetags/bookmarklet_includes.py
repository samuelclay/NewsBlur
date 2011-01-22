import os
from django.conf import settings
from django import template

register = template.Library()

@register.simple_tag
def include_bookmarklet_js():
    text = []
    js_files = settings.COMPRESS_JS['bookmarklet']['source_filenames']
    for filename in js_files:
        abs_filename = os.path.join(settings.MEDIA_ROOT, filename)
        f = open(abs_filename, 'r')
        text.append(f.read())
    
    return ''.join(text)
    
@register.simple_tag
def include_bookmarklet_css():
    text = []
    css_files = settings.COMPRESS_CSS['bookmarklet']['source_filenames']
    for filename in css_files:
        abs_filename = os.path.join(settings.MEDIA_ROOT, filename)
        f = open(abs_filename, 'r')
        css = f.read()
        css = css.replace('\"', '\\"').replace('\n', ' ')
        text.append(css)
    
    return ''.join(text)
    