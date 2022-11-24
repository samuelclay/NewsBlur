import os
import re
import struct
import datetime
import random
from utils import log as logging
from django.contrib.sites.models import Site
from django.conf import settings
from django import template
from apps.reader.forms import FeatureForm
from apps.reader.models import Feature
from apps.social.models import MSocialProfile
from vendor.timezones.utilities import localtime_for_timezone
from utils.user_functions import get_user
from django.utils.safestring import mark_safe
from pipeline.templatetags.pipeline import stylesheet, javascript
from pipeline.templatetags.pipeline import JavascriptNode, StylesheetNode

register = template.Library()

@register.simple_tag
def current_domain(dev=False, strip_www=False):
    current_site = Site.objects.get_current()
    domain = current_site and current_site.domain
    if dev and settings.SERVER_NAME in ["dev"] and domain:
        domain = domain.replace("www", "dev")
    if strip_www:
        domain = domain.replace("www.", "")
    return domain

@register.simple_tag(takes_context=True)
def localdatetime(context, date, date_format):
    user = get_user(context['user'])
    date = localtime_for_timezone(date, user.profile.timezone).strftime(date_format)
    return date
    
@register.inclusion_tag('reader/feeds_skeleton.xhtml', takes_context=True)
def render_feeds_skeleton(context):
    user = get_user(context['user'])
    social_profile = MSocialProfile.get_user(user.pk)

    return {
        'user': user,
        'social_profile': social_profile,
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

@register.inclusion_tag('reader/getting_started.xhtml', takes_context=True)
def render_getting_started(context):
    user    = get_user(context['user'])
    profile = MSocialProfile.profile(user.pk)

    return {
        'user': user,
        'user_profile': user.profile,
        'social_profile': profile,
    }

@register.inclusion_tag('reader/dashboard_rivers.xhtml', takes_context=True)
def render_dashboard_rivers_left(context, dashboard_rivers):
    user    = get_user(context['user'])

    return {
        'user': user,
        'dashboard_rivers': dashboard_rivers,
        'side': 'left'
    }

@register.inclusion_tag('reader/dashboard_rivers.xhtml', takes_context=True)
def render_dashboard_rivers_right(context, dashboard_rivers):
    user    = get_user(context['user'])

    return {
        'user': user,
        'dashboard_rivers': dashboard_rivers,
        'side': 'right'
    }

@register.inclusion_tag('reader/dashboard_river.xhtml', takes_context=True)
def render_dashboard_river(context, dashboard_river):
    user    = get_user(context['user'])

    return {
        'user': user,
        'dashboard_river': dashboard_river,
    }

@register.inclusion_tag('reader/account_module.xhtml', takes_context=True)
def render_account_module(context):
    user    = get_user(context['user'])
    reasons = [
        "Enable every site by going premium",
        "Sites updated up to 5x more often",
        "Read the River of News (reading by folder)",
        "Search sites and folders",
        "Save stories with searchable tags",
        "Privacy options for your blurblog",
        "Custom RSS feeds for saved stories",
        "Text view conveniently recreates the full story",
        f"You feed Lyric, NewsBlur's hungry hound, for 6 days<img class='NB-feedchooser-premium-poor-hungry-dog' src='{settings.MEDIA_URL}img/reader/lyric.jpg'>",
    ]
    rand_int = (datetime.datetime.now().timetuple().tm_yday) % len(reasons)
    return {
        'user': user,
        'user_profile': user.profile,
        'social_profile': context['social_profile'],
        'feed_count': context['feed_count'],
        'reason': reasons[rand_int],
        'rand_int': rand_int+1
    }
    
@register.inclusion_tag('reader/premium_archive_module.xhtml', takes_context=True)
def render_premium_archive_module(context):
    user    = get_user(context['user'])

    reasons = [
        "Stories can stay unread for however long you choose",
        "Every story from every site is archived and searchable forever",
        "Feeds that support paging are back-filled in for a complete archive",
        "Export trained stories from folders as RSS feeds",
        "Choose when stories are automatically marked as read",
    ]
    rand_int = (datetime.datetime.now().timetuple().tm_yday) % len(reasons)
    
    return {
        'user': user,
        'user_profile': user.profile,
        'reason': reasons[rand_int],
        'rand_int': rand_int+1+1
    }
    
@register.inclusion_tag('reader/manage_module.xhtml', takes_context=True)
def render_manage_module(context):
    user    = get_user(context['user'])

    return {
        'user': user,
        'user_profile': user.profile,
    }
    
@register.inclusion_tag('reader/footer.xhtml', takes_context=True)
def render_footer(context, page=None):
    return {
        'page': page,
        'MEDIA_URL': settings.MEDIA_URL,
    }

@register.filter
def get(h, key):
    print(h, key)
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
def color2rgba(color, alpha):
    if "#" in color:
        return hex2rgba(color, alpha)
    elif "rgb" in color:
        return rgb2rgba(color, alpha)
    
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
    return list(range( value))

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
def settings_value(name):
    return getattr(settings, name, "")

@register.filter
def smooth_timedelta(timedeltaobj):
    """Convert a datetime.timedelta object into Days, Hours, Minutes, Seconds."""
    if isinstance(timedeltaobj, datetime.datetime):
        timedeltaobj = timedeltaobj - datetime.datetime.now()
    secs = timedeltaobj.total_seconds()
    overdue = secs < 0
    secs = abs(secs)
    timetot = ""
    if not overdue:
        timetot += "in "
        
    if secs > 86400: # 60sec * 60min * 24hrs
        days = secs // 86400
        timetot += "{} days".format(int(days))
        secs = secs - days*86400

    if secs > 3600:
        hrs = secs // 3600
        timetot += " {} hours".format(int(hrs))
        secs = secs - hrs*3600

    if secs > 60:
        mins = secs // 60
        timetot += " {} min".format(int(mins))
        secs = secs - mins*60

    if secs > 0:
        timetot += " {} sec".format(int(secs))

    if overdue:
        timetot += " ago"
    
    return timetot

@register.tag
def include_javascripts(parser, token):
    """Prints out a template of <script> tags based on an asset package name."""
    return javascript(parser, token)
    # asset_type = 'javascripts'
    # return mark_safe(settings.JAMMIT.render_tags(asset_type, asset_package))

class RawJSNode(JavascriptNode):
    def render(self, context):
        output = super(RawJSNode, self).render(context)
        paths = re.findall(r"src=\"/(.*?)\"", output, re.MULTILINE)
        assert paths
        output = ""
        for filename in paths:
            abs_filename = os.path.join(settings.NEWSBLUR_DIR, filename)
            f = open(abs_filename, 'r')
            output += f.read()
        return output
    
@register.tag
def include_javascripts_raw(parser, token):
    """Prints out the JS code found in the static asset packages."""
    tag_name, name = token.split_contents()
    scripts = RawJSNode(name)
    return scripts

class RawStylesheetNode(StylesheetNode):
    def render(self, context):
        output = super(RawStylesheetNode, self).render(context)
        paths = re.findall(r"href=\"/(.*?)\"", output, re.MULTILINE)
        assert paths
        output = ""
        for filename in paths:
            abs_filename = os.path.join(settings.NEWSBLUR_DIR, filename)
            f = open(abs_filename, 'r')
            output += f.read().replace('"', '\\"').replace('\n', '')
        return output
    
@register.tag
def include_stylesheets_raw(parser, token):
    """Prints out the CSS code found in the static asset packages."""
    tag_name, name = token.split_contents()
    scripts = RawStylesheetNode(name)
    return scripts
        
@register.tag
def include_stylesheets(parser, token):
    """Prints out a template of <link> tags based on an asset package name."""
    return stylesheet(parser, token)
    # asset_type = 'stylesheets'
    # return mark_safe(settings.JAMMIT.render_tags(asset_type, asset_package))
