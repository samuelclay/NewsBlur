
from django.template import Node
from django.template import Library

from vendor.timezones.utilities import localtime_for_timezone

register = Library()

def localtime(value, timezone):
    return localtime_for_timezone(value, timezone)
register.filter("localtime", localtime)

