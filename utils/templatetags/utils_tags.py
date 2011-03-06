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