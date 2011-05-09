from django.contrib.sites.models import Site
from django import template
from utils.user_functions import get_user
from utils.timezones.utilities import localtime_for_timezone

register = template.Library()

@register.simple_tag
def current_domain():
    return Site.objects.get_current().domain

@register.simple_tag(takes_context=True)
def localdatetime(context, date, date_format):
    user = get_user(context['user'])
    date = localtime_for_timezone(date, user.profile.timezone).strftime(date_format)
    return date
        
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
