from datetime import timedelta
from mongoengine.base import BaseField
from mongoengine.fields import IntField, StringField, EmailField


class TimedeltaField(BaseField):
    """A timedelta field.

    Looks to the outside world like a datatime.timedelta, but stores
    in the database as an integer (or float) number of seconds.

    """
    def validate(self, value):
        if not isinstance(value, (timedelta, int, float)):
            self.error('cannot parse timedelta "%r"' % value)

    def to_mongo(self, value):
        return self.prepare_query_value(None, value)

    def to_python(self, value):
        return timedelta(seconds=value)

    def prepare_query_value(self, op, value):
        if value is None:
            return value
        if isinstance(value, timedelta):
            return self.total_seconds(value)
        if isinstance(value, (int, float)):
            return value

    @staticmethod
    def total_seconds(value):
        """Implements Python 2.7's datetime.timedelta.total_seconds()
        for backwards compatibility with Python 2.5 and 2.6.

        """
        try:
            return value.total_seconds()
        except AttributeError:
            return (value.days * 24 * 3600) + \
                   (value.seconds) + \
                   (value.microseconds / 1000000.0)


class LowerStringField(StringField):
    def __set__(self, instance, value):
        value = self.to_python(value)
        return super(LowerStringField, self).__set__(instance, value)

    def to_python(self, value):
        if value:
            value = value.lower()
        return value

    def prepare_query_value(self, op, value):
        value = value.lower() if value else value
        return super(LowerStringField, self).prepare_query_value(op, value)


class LowerEmailField(LowerStringField):

    def validate(self, value):
        if not EmailField.EMAIL_REGEX.match(value):
            self.error('Invalid Mail-address: %s' % value)
        super(LowerEmailField, self).validate(value)


class EnumField(object):
    """
    A class to register Enum type (from the package enum34) into mongo

    :param choices: must be of :class:`enum.Enum`: type
        and will be used as possible choices
    """

    def __init__(self, enum, *args, **kwargs):
        self.enum = enum
        kwargs['choices'] = [choice for choice in enum]
        super(EnumField, self).__init__(*args, **kwargs)

    def __get_value(self, enum):
        return enum.value if hasattr(enum, 'value') else enum

    def to_python(self, value):
        return self.enum(super(EnumField, self).to_python(value))

    def to_mongo(self, value):
        return self.__get_value(value)

    def prepare_query_value(self, op, value):
        return super(EnumField, self).prepare_query_value(
                op, self.__get_value(value))

    def validate(self, value):
        return super(EnumField, self).validate(self.__get_value(value))

    def _validate(self, value, **kwargs):
        return super(EnumField, self)._validate(
                self.enum(self.__get_value(value)), **kwargs)


class IntEnumField(EnumField, IntField):
    """A variation on :class:`EnumField` for only int containing enumeration.
    """
    pass


class StringEnumField(EnumField, StringField):
    """A variation on :class:`EnumField` for only string containing enumeration.
    """
    pass