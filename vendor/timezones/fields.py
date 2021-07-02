from django.conf import settings
from django.db import models
from django.db.models import signals
from django.utils.encoding import smart_str, smart_bytes

import pytz

from vendor.timezones import forms, zones
from vendor.timezones.utilities import coerce_timezone_value, validate_timezone_max_length

MAX_TIMEZONE_LENGTH = getattr(settings, "MAX_TIMEZONE_LENGTH", 100)
default_tz = pytz.timezone(getattr(settings, "TIME_ZONE", "UTC"))


class TimeZoneField(models.CharField):
    
    def __init__(self, *args, **kwargs):
        validate_timezone_max_length(MAX_TIMEZONE_LENGTH, zones.ALL_TIMEZONE_CHOICES)
        defaults = {
            "max_length": MAX_TIMEZONE_LENGTH,
            "default": settings.TIME_ZONE,
            "choices": zones.PRETTY_TIMEZONE_CHOICES
        }
        defaults.update(kwargs)
        return super(TimeZoneField, self).__init__(*args, **defaults)
    
    def validate(self, value, model_instance):
        # coerce value back to a string to validate correctly
        return super(TimeZoneField, self).validate(smart_bytes(value), model_instance)
    
    def run_validators(self, value):
        # coerce value back to a string to validate correctly
        return super(TimeZoneField, self).run_validators(smart_bytes(value))
    
    def from_db_value(self, value, expression, connection, context):
        value = super(TimeZoneField, self).to_python(value)
        if value is None:
            return None # null=True
        return coerce_timezone_value(value)

    def to_python(self, value):
        value = super(TimeZoneField, self).to_python(value)
        if value is None:
            return None # null=True
        return coerce_timezone_value(value)

    def from_db_value(self, value, expression, connection):
        if value is None:
            return None
        return coerce_timezone_value(value)

    def get_prep_value(self, value):
        if value is not None:
            return smart_str(value)
        return value
    
    def get_db_prep_save(self, value, connection=None):
        """
        Prepares the given value for insertion into the database.
        """
        return self.get_prep_value(value)
    
    def flatten_data(self, follow, obj=None):
        value = self.value_from_object(obj)
        if value is None:
            value = ""
        return {self.attname: smart_str(value)}


class LocalizedDateTimeField(models.DateTimeField):
    """
    A model field that provides automatic localized timezone support.
    timezone can be a timezone string, a callable (returning a timezone string),
    or a queryset keyword relation for the model, or a pytz.timezone()
    result.
    """
    lookup_name = None
    def __init__(self, verbose_name=None, name=None, timezone=None, **kwargs):

        if isinstance(timezone, str):
            timezone = smart_bytes(timezone)
        if timezone in pytz.all_timezones_set:
            self.timezone = pytz.timezone(timezone)
        else:
            self.timezone = timezone
        super(LocalizedDateTimeField, self).__init__(verbose_name, name, **kwargs)
    
    def formfield(self, **kwargs):
        defaults = {"form_class": forms.LocalizedDateTimeField}
        if (not isinstance(self.timezone, str) and str(self.timezone) in pytz.all_timezones_set):
            defaults["timezone"] = str(self.timezone)
        defaults.update(kwargs)
        return super(LocalizedDateTimeField, self).formfield(**defaults)
    
    def get_db_prep_save(self, value, connection=None):
        """
        Returns field's value prepared for saving into a database.
        """
        ## convert to settings.TIME_ZONE
        if value is not None:
            if value.tzinfo is None:
                value = default_tz.localize(value)
            else:
                value = value.astimezone(default_tz)
        return super(LocalizedDateTimeField, self).get_db_prep_save(value, connection=connection)
    
def prep_localized_datetime(sender, **kwargs):
    for field in sender._meta.fields:
        if not isinstance(field, LocalizedDateTimeField) or field.timezone is None:
            continue
        dt_field_name = "_datetimezone_%s" % field.attname
        def get_dtz_field(instance):
            return getattr(instance, dt_field_name)
        def set_dtz_field(instance, dt):
            if dt.tzinfo is None:
                dt = default_tz.localize(dt)
            time_zone = field.timezone
            if isinstance(field.timezone, str):
                tz_name = instance._default_manager.filter(
                    pk=model_instance._get_pk_val()
                ).values_list(field.timezone)[0][0]
                try:
                    time_zone = pytz.timezone(tz_name)
                except:
                    time_zone = default_tz
                if time_zone is None:
                    # lookup failed
                    time_zone = default_tz
                    #raise pytz.UnknownTimeZoneError(
                    #    "Time zone %r from relation %r was not found"
                    #    % (tz_name, field.timezone)
                    #)
            elif callable(time_zone):
                tz_name = time_zone()
                if isinstance(tz_name, str):
                    try:
                        time_zone = pytz.timezone(tz_name)
                    except:
                        time_zone = default_tz
                else:
                    time_zone = tz_name
                if time_zone is None:
                    # lookup failed
                    time_zone = default_tz
                    #raise pytz.UnknownTimeZoneError(
                    #    "Time zone %r from callable %r was not found"
                    #    % (tz_name, field.timezone)
                    #)
            setattr(instance, dt_field_name, dt.astimezone(time_zone))
        setattr(sender, field.attname, property(get_dtz_field, set_dtz_field))

## RED_FLAG: need to add a check at manage.py validation time that
##           time_zone value is a valid query keyword (if it is one)
signals.class_prepared.connect(prep_localized_datetime)

models.DateTimeField.register_lookup(LocalizedDateTimeField)