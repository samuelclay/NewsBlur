from datetime import datetime

import pytz



ALL_TIMEZONE_CHOICES = tuple(zip(pytz.all_timezones, pytz.all_timezones))
COMMON_TIMEZONE_CHOICES = tuple(zip(pytz.common_timezones, pytz.common_timezones))
PRETTY_TIMEZONE_CHOICES = []

for tz in pytz.common_timezones:
    now = datetime.now(pytz.timezone(tz))
    PRETTY_TIMEZONE_CHOICES.append((tz, "(GMT%s) %s" % (now.strftime("%z"), tz)))