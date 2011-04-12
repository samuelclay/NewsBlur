from django.conf import settings
from django.utils.encoding import smart_str

import pytz



default_tz = pytz.timezone(getattr(settings, "TIME_ZONE", "UTC"))



def localdatetime(field_name):
    def get_datetime(instance):
        return getattr(instance, field_name)
    def set_datetime(instance, value):
        return setattr(instance, field_name, value)
    def make_local_property(get_tz):
        def get_local(instance):
            tz = get_tz(instance)
            if not hasattr(tz, "localize"):
                tz = pytz.timezone(smart_str(tz))
            dt = get_datetime(instance)
            if dt.tzinfo is None:
                dt = default_tz.localize(dt)
            return dt.astimezone(tz)
        def set_local(instance, dt):
            if dt.tzinfo is None:
                tz = get_tz(instance)
                if not hasattr(tz, "localize"):
                    tz = pytz.timezone(smart_str(tz))
                dt = tz.localize(dt)
            dt = dt.astimezone(default_tz)
            return set_datetime(instance, dt)
        return property(get_local, set_local)
    return make_local_property
