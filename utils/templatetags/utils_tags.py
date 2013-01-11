import struct
from django.contrib.sites.models import Site
from django.conf import settings
from django import template
from apps.reader.forms import FeatureForm
from apps.reader.models import Feature
from apps.social.models import MInteraction, MActivity, MSocialProfile
from vendor.timezones.utilities import localtime_for_timezone
from utils.user_functions import get_user

register = template.Library()

@register.simple_tag
def current_domain():
    current_site = Site.objects.get_current()
    return current_site and current_site.domain

@register.simple_tag(takes_context=True)
def localdatetime(context, date, date_format):
    user = get_user(context['user'])
    date = localtime_for_timezone(date, user.profile.timezone).strftime(date_format)
    return date
    
@register.inclusion_tag('reader/feeds_skeleton.xhtml', takes_context=True)
def render_feeds_skeleton(context):
    user         = get_user(context['user'])

    return {
        'user': user,
        'MEDIA_URL': settings.MEDIA_URL,
    }

@register.inclusion_tag('reader/features_module.xhtml', takes_context=True)
def render_features_module(context):
    user         = get_user(context['user'])
    features     = Feature.objects.all()[:3]
    feature_form = FeatureForm() if user.is_staff else None

    return {
        'user': user,
        'features': features,
        'feature_form': feature_form,
    }
          
@register.inclusion_tag('reader/recommended_users.xhtml', takes_context=True)
def render_recommended_users(context):
    user    = get_user(context['user'])
    profile = MSocialProfile.profile(user.pk)

    return {
        'user': user,
        'profile': profile,
    }
          
@register.inclusion_tag('reader/interactions_module.xhtml', takes_context=True)
def render_interactions_module(context, page=1):
    user = get_user(context['user'])
    interactions, has_next_page = MInteraction.user(user.pk, page)
    
    return {
        'user': user,
        'interactions': interactions,
        'page': page,
        'has_next_page': has_next_page,
        'MEDIA_URL': context['MEDIA_URL'],
    }
    
@register.inclusion_tag('reader/activities_module.xhtml', takes_context=True)
def render_activities_module(context, page=1):
    user = get_user(context['user'])
    activities, has_next_page = MActivity.user(user.pk, page)
    
    return {
        'user': user,
        'activities': activities,
        'page': page,
        'has_next_page': has_next_page,
        'username': 'You',
        'MEDIA_URL': context['MEDIA_URL'],
    }

@register.filter
def get(h, key):
    print h, key
    return h[key]

@register.filter
def hex2rgba(hex, alpha):
    colors = struct.unpack('BBB', hex.decode('hex'))
    return "rgba(%s, %s, %s, %s)" % (colors[0], colors[1], colors[2], alpha)
    
@register.filter
def rgb2rgba(rgb, alpha):
    rgb = rgb.replace('rgb', 'rgba')
    rgb = rgb.replace(')', ", %s)" % alpha)
    return rgb
    
@register.filter
def get_range( value ):
    """
    Filter - returns a list containing range made from given value
    Usage (in template):

    <ul>{% for i in 3|get_range %}
      <li>{{ i }}. Do something</li>
    {% endfor %}</ul>

    Results with the HTML:
    <ul>
      <li>0. Do something</li>
      <li>1. Do something</li>
      <li>2. Do something</li>
    </ul>

    Instead of 3 one may use the variable set in the views
    """
    return range( value )

@register.filter
def commify(n):
    """ 
    Add commas to an integer n.
    >>> commify(1)
    '1'
    >>> commify(123)
    '123'
    >>> commify(1234)
    '1,234'
    >>> commify(1234567890)
    '1,234,567,890'
    >>> commify(123.0)
    '123.0'
    >>> commify(1234.5)
    '1,234.5'
    >>> commify(1234.56789)
    '1,234.56789'
    >>> commify('%.2f' % 1234.5)
    '1,234.50'
    >>> commify(None)
    
    """
    if n is None: return None
    n = str(n)
    if '.' in n:
        dollars, cents = n.split('.')
    else:
        dollars, cents = n, None
    
    r = []
    for i, c in enumerate(reversed(dollars)):
        if i and (not (i % 3)):
            r.insert(0, ',')
        r.insert(0, c)
    out = ''.join(r)
    if cents:
        out += '.' + cents
    return out


@register.simple_tag
def include_javascripts(asset_package):
    """Prints out a template of <script> tags based on an asset package name."""
    asset_type = 'javascripts'
    return settings.JAMMIT.render_tags(asset_type, asset_package)
        
        
@register.simple_tag
def include_stylesheets(asset_package):
    """Prints out a template of <link> tags based on an asset package name."""
    asset_type = 'stylesheets'
    return settings.JAMMIT.render_tags(asset_type, asset_package)
