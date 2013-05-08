import re
from django.utils import datetime_safe
from django.template import loader, Context
from haystack.exceptions import SearchFieldError


class NOT_PROVIDED:
    pass


DATETIME_REGEX = re.compile('^(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})(T|\s+)(?P<hour>\d{2}):(?P<minute>\d{2}):(?P<second>\d{2}).*?$')


# All the SearchFields variants.

class SearchField(object):
    """The base implementation of a search field."""
    field_type = None

    def __init__(self, model_attr=None, use_template=False, template_name=None,
                 document=False, indexed=True, stored=True, faceted=False,
                 default=NOT_PROVIDED, null=False, index_fieldname=None,
                 facet_class=None, boost=1.0, weight=None):
        # Track what the index thinks this field is called.
        self.instance_name = None
        self.model_attr = model_attr
        self.use_template = use_template
        self.template_name = template_name
        self.document = document
        self.indexed = indexed
        self.stored = stored
        self.faceted = faceted
        self._default = default
        self.null = null
        self.index_fieldname = index_fieldname
        self.boost = weight or boost
        self.is_multivalued = False

        # We supply the facet_class for making it easy to create a faceted
        # field based off of this field.
        self.facet_class = facet_class

        if self.facet_class is None:
            self.facet_class = FacetCharField

        self.set_instance_name(None)

    def set_instance_name(self, instance_name):
        self.instance_name = instance_name

        if self.index_fieldname is None:
            self.index_fieldname = self.instance_name

    def has_default(self):
        """Returns a boolean of whether this field has a default value."""
        return self._default is not NOT_PROVIDED

    @property
    def default(self):
        """Returns the default value for the field."""
        if callable(self._default):
            return self._default()

        return self._default

    def prepare(self, obj):
        """
        Takes data from the provided object and prepares it for storage in the
        index.
        """
        # Give priority to a template.
        if self.use_template:
            return self.prepare_template(obj)
        elif self.model_attr is not None:
            # Check for `__` in the field for looking through the relation.
            attrs = self.model_attr.split('__')
            current_object = obj

            for attr in attrs:
                if not hasattr(current_object, attr):
                    raise SearchFieldError("The model '%s' does not have a model_attr '%s'." % (repr(obj), attr))

                current_object = getattr(current_object, attr, None)

                if current_object is None:
                    if self.has_default():
                        current_object = self._default
                        # Fall out of the loop, given any further attempts at
                        # accesses will fail misreably.
                        break
                    elif self.null:
                        current_object = None
                        # Fall out of the loop, given any further attempts at
                        # accesses will fail misreably.
                        break
                    else:
                        raise SearchFieldError("The model '%s' has an empty model_attr '%s' and doesn't allow a default or null value." % (repr(obj), attr))

            if callable(current_object):
                return current_object()

            return current_object

        if self.has_default():
            return self.default
        else:
            return None

    def prepare_template(self, obj):
        """
        Flattens an object for indexing.

        This loads a template
        (``search/indexes/{app_label}/{model_name}_{field_name}.txt``) and
        returns the result of rendering that template. ``object`` will be in
        its context.
        """
        if self.instance_name is None and self.template_name is None:
            raise SearchFieldError("This field requires either its instance_name variable to be populated or an explicit template_name in order to load the correct template.")

        if self.template_name is not None:
            template_names = self.template_name

            if not isinstance(template_names, (list, tuple)):
                template_names = [template_names]
        else:
            template_names = ['search/indexes/%s/%s_%s.txt' % (obj._meta.app_label, obj._meta.module_name, self.instance_name)]

        t = loader.select_template(template_names)
        return t.render(Context({'object': obj}))

    def convert(self, value):
        """
        Handles conversion between the data found and the type of the field.

        Extending classes should override this method and provide correct
        data coercion.
        """
        return value


class CharField(SearchField):
    field_type = 'string'

    def __init__(self, **kwargs):
        if kwargs.get('facet_class') is None:
            kwargs['facet_class'] = FacetCharField

        super(CharField, self).__init__(**kwargs)

    def prepare(self, obj):
        return self.convert(super(CharField, self).prepare(obj))

    def convert(self, value):
        if value is None:
            return None

        return unicode(value)


class LocationField(SearchField):
    field_type = 'location'

    def prepare(self, obj):
        from haystack.utils.geo import ensure_point

        value = super(LocationField, self).prepare(obj)

        if value is None:
            return None

        pnt = ensure_point(value)
        pnt_lng, pnt_lat = pnt.get_coords()
        return "%s,%s" % (pnt_lat, pnt_lng)

    def convert(self, value):
        from haystack.utils.geo import ensure_point, Point

        if value is None:
            return None

        if hasattr(value, 'geom_type'):
            value = ensure_point(value)
            return value

        if isinstance(value, basestring):
            lat, lng = value.split(',')
        elif isinstance(value, (list, tuple)):
            # GeoJSON-alike
            lat, lng = value[1], value[0]
        elif isinstance(value, dict):
            lat = value.get('lat', 0)
            lng = value.get('lon', 0)

        value = Point(float(lng), float(lat))
        return value


class NgramField(CharField):
    field_type = 'ngram'

    def __init__(self, **kwargs):
        if kwargs.get('faceted') is True:
            raise SearchFieldError("%s can not be faceted." % self.__class__.__name__)

        super(NgramField, self).__init__(**kwargs)


class EdgeNgramField(NgramField):
    field_type = 'edge_ngram'


class IntegerField(SearchField):
    field_type = 'integer'

    def __init__(self, **kwargs):
        if kwargs.get('facet_class') is None:
            kwargs['facet_class'] = FacetIntegerField

        super(IntegerField, self).__init__(**kwargs)

    def prepare(self, obj):
        return self.convert(super(IntegerField, self).prepare(obj))

    def convert(self, value):
        if value is None:
            return None

        return int(value)


class FloatField(SearchField):
    field_type = 'float'

    def __init__(self, **kwargs):
        if kwargs.get('facet_class') is None:
            kwargs['facet_class'] = FacetFloatField

        super(FloatField, self).__init__(**kwargs)

    def prepare(self, obj):
        return self.convert(super(FloatField, self).prepare(obj))

    def convert(self, value):
        if value is None:
            return None

        return float(value)


class DecimalField(SearchField):
    field_type = 'string'

    def __init__(self, **kwargs):
        if kwargs.get('facet_class') is None:
            kwargs['facet_class'] = FacetDecimalField

        super(DecimalField, self).__init__(**kwargs)

    def prepare(self, obj):
        return self.convert(super(DecimalField, self).prepare(obj))

    def convert(self, value):
        if value is None:
            return None

        return unicode(value)


class BooleanField(SearchField):
    field_type = 'boolean'

    def __init__(self, **kwargs):
        if kwargs.get('facet_class') is None:
            kwargs['facet_class'] = FacetBooleanField

        super(BooleanField, self).__init__(**kwargs)

    def prepare(self, obj):
        return self.convert(super(BooleanField, self).prepare(obj))

    def convert(self, value):
        if value is None:
            return None

        return bool(value)


class DateField(SearchField):
    field_type = 'date'

    def __init__(self, **kwargs):
        if kwargs.get('facet_class') is None:
            kwargs['facet_class'] = FacetDateField

        super(DateField, self).__init__(**kwargs)

    def convert(self, value):
        if value is None:
            return None

        if isinstance(value, basestring):
            match = DATETIME_REGEX.search(value)

            if match:
                data = match.groupdict()
                return datetime_safe.date(int(data['year']), int(data['month']), int(data['day']))
            else:
                raise SearchFieldError("Date provided to '%s' field doesn't appear to be a valid date string: '%s'" % (self.instance_name, value))

        return value


class DateTimeField(SearchField):
    field_type = 'datetime'

    def __init__(self, **kwargs):
        if kwargs.get('facet_class') is None:
            kwargs['facet_class'] = FacetDateTimeField

        super(DateTimeField, self).__init__(**kwargs)

    def convert(self, value):
        if value is None:
            return None

        if isinstance(value, basestring):
            match = DATETIME_REGEX.search(value)

            if match:
                data = match.groupdict()
                return datetime_safe.datetime(int(data['year']), int(data['month']), int(data['day']), int(data['hour']), int(data['minute']), int(data['second']))
            else:
                raise SearchFieldError("Datetime provided to '%s' field doesn't appear to be a valid datetime string: '%s'" % (self.instance_name, value))

        return value


class MultiValueField(SearchField):
    field_type = 'string'

    def __init__(self, **kwargs):
        if kwargs.get('facet_class') is None:
            kwargs['facet_class'] = FacetMultiValueField

        if kwargs.get('use_template') is True:
            raise SearchFieldError("'%s' fields can not use templates to prepare their data." % self.__class__.__name__)

        super(MultiValueField, self).__init__(**kwargs)
        self.is_multivalued = True

    def prepare(self, obj):
        return self.convert(super(MultiValueField, self).prepare(obj))

    def convert(self, value):
        if value is None:
            return None

        return list(value)


class FacetField(SearchField):
    """
    ``FacetField`` is slightly different than the other fields because it can
    work in conjunction with other fields as its data source.

    Accepts an optional ``facet_for`` kwarg, which should be the field name
    (not ``index_fieldname``) of the field it should pull data from.
    """
    instance_name = None

    def __init__(self, **kwargs):
        handled_kwargs = self.handle_facet_parameters(kwargs)
        super(FacetField, self).__init__(**handled_kwargs)

    def handle_facet_parameters(self, kwargs):
        if kwargs.get('faceted', False):
            raise SearchFieldError("FacetField (%s) does not accept the 'faceted' argument." % self.instance_name)

        if not kwargs.get('null', True):
            raise SearchFieldError("FacetField (%s) does not accept False for the 'null' argument." % self.instance_name)

        if not kwargs.get('indexed', True):
            raise SearchFieldError("FacetField (%s) does not accept False for the 'indexed' argument." % self.instance_name)

        if kwargs.get('facet_class'):
            raise SearchFieldError("FacetField (%s) does not accept the 'facet_class' argument." % self.instance_name)

        self.facet_for = None
        self.facet_class = None

        # Make sure the field is nullable.
        kwargs['null'] = True

        if 'facet_for' in kwargs:
            self.facet_for = kwargs['facet_for']
            del(kwargs['facet_for'])

        return kwargs

    def get_facet_for_name(self):
        return self.facet_for or self.instance_name


class FacetCharField(FacetField, CharField):
    pass


class FacetIntegerField(FacetField, IntegerField):
    pass


class FacetFloatField(FacetField, FloatField):
    pass


class FacetDecimalField(FacetField, DecimalField):
    pass


class FacetBooleanField(FacetField, BooleanField):
    pass


class FacetDateField(FacetField, DateField):
    pass


class FacetDateTimeField(FacetField, DateTimeField):
    pass


class FacetMultiValueField(FacetField, MultiValueField):
    pass
