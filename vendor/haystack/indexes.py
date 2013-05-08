import copy
import threading
import warnings
from django.utils.encoding import force_unicode
from django.core.exceptions import ImproperlyConfigured
from haystack import connections, connection_router
from haystack.constants import ID, DJANGO_CT, DJANGO_ID, Indexable, DEFAULT_ALIAS
from haystack.fields import *
from haystack.manager import HaystackManager
from haystack.utils import get_identifier, get_facet_field_name


class DeclarativeMetaclass(type):
    def __new__(cls, name, bases, attrs):
        attrs['fields'] = {}

        # Inherit any fields from parent(s).
        try:
            parents = [b for b in bases if issubclass(b, SearchIndex)]
            # Simulate the MRO.
            parents.reverse()

            for p in parents:
                fields = getattr(p, 'fields', None)

                if fields:
                    attrs['fields'].update(fields)
        except NameError:
            pass

        # Build a dictionary of faceted fields for cross-referencing.
        facet_fields = {}

        for field_name, obj in attrs.items():
            # Only need to check the FacetFields.
            if hasattr(obj, 'facet_for'):
                if not obj.facet_for in facet_fields:
                    facet_fields[obj.facet_for] = []

                facet_fields[obj.facet_for].append(field_name)

        for field_name, obj in attrs.items():
            if isinstance(obj, SearchField):
                field = attrs.pop(field_name)
                field.set_instance_name(field_name)
                attrs['fields'][field_name] = field

                # Only check non-faceted fields for the following info.
                if not hasattr(field, 'facet_for'):
                    if field.faceted == True:
                        # If no other field is claiming this field as
                        # ``facet_for``, create a shadow ``FacetField``.
                        if not field_name in facet_fields:
                            shadow_facet_name = get_facet_field_name(field_name)
                            shadow_facet_field = field.facet_class(facet_for=field_name)
                            shadow_facet_field.set_instance_name(shadow_facet_name)
                            attrs['fields'][shadow_facet_name] = shadow_facet_field

        # Assigning default 'objects' query manager if it does not already exist
        if not attrs.has_key('objects'):
            try:
                attrs['objects'] = HaystackManager(attrs['Meta'].index_label)
            except (KeyError, AttributeError):
                attrs['objects'] = HaystackManager(DEFAULT_ALIAS)

        return super(DeclarativeMetaclass, cls).__new__(cls, name, bases, attrs)


class SearchIndex(threading.local):
    """
    Base class for building indexes.

    An example might look like this::

        import datetime
        from haystack import indexes
        from myapp.models import Note

        class NoteIndex(indexes.SearchIndex, indexes.Indexable):
            text = indexes.CharField(document=True, use_template=True)
            author = indexes.CharField(model_attr='user')
            pub_date = indexes.DateTimeField(model_attr='pub_date')

            def get_model(self):
                return Note

            def index_queryset(self, using=None):
                return self.get_model().objects.filter(pub_date__lte=datetime.datetime.now())

    """
    __metaclass__ = DeclarativeMetaclass

    def __init__(self):
        self.prepared_data = None
        content_fields = []

        for field_name, field in self.fields.items():
            if field.document is True:
                content_fields.append(field_name)

        if not len(content_fields) == 1:
            raise SearchFieldError("The index '%s' must have one (and only one) SearchField with document=True." % self.__class__.__name__)

    def get_model(self):
        """
        Should return the ``Model`` class (not an instance) that the rest of the
        ``SearchIndex`` should use.

        This method is required & you must override it to return the correct class.
        """
        raise NotImplementedError("You must provide a 'model' method for the '%r' index." % self)

    def index_queryset(self, using=None):
        """
        Get the default QuerySet to index when doing a full update.

        Subclasses can override this method to avoid indexing certain objects.
        """
        return self.get_model()._default_manager.all()

    def read_queryset(self, using=None):
        """
        Get the default QuerySet for read actions.

        Subclasses can override this method to work with other managers.
        Useful when working with default managers that filter some objects.
        """
        return self.index_queryset(using=using)

    def build_queryset(self, using=None, start_date=None, end_date=None):
        """
        Get the default QuerySet to index when doing an index update.

        Subclasses can override this method to take into account related
        model modification times.

        The default is to use ``SearchIndex.index_queryset`` and filter
        based on ``SearchIndex.get_updated_field``
        """
        extra_lookup_kwargs = {}
        model = self.get_model()
        updated_field = self.get_updated_field()

        update_field_msg = ("No updated date field found for '%s' "
                            "- not restricting by age.") % model.__name__

        if start_date:
            if updated_field:
                extra_lookup_kwargs['%s__gte' % updated_field] = start_date
            else:
                warnings.warn(update_field_msg)

        if end_date:
            if updated_field:
                extra_lookup_kwargs['%s__lte' % updated_field] = end_date
            else:
                warnings.warn(update_field_msg)

        index_qs = None

        if hasattr(self, 'get_queryset'):
            warnings.warn("'SearchIndex.get_queryset' was deprecated in Haystack v2. Please rename the method 'index_queryset'.")
            index_qs = self.get_queryset()
        else:
            index_qs = self.index_queryset(using=using)

        if not hasattr(index_qs, 'filter'):
            raise ImproperlyConfigured("The '%r' class must return a 'QuerySet' in the 'index_queryset' method." % self)

        # `.select_related()` seems like a good idea here but can fail on
        # nullable `ForeignKey` as well as what seems like other cases.
        return index_qs.filter(**extra_lookup_kwargs).order_by(model._meta.pk.name)

    def prepare(self, obj):
        """
        Fetches and adds/alters data before indexing.
        """
        self.prepared_data = {
            ID: get_identifier(obj),
            DJANGO_CT: "%s.%s" % (obj._meta.app_label, obj._meta.module_name),
            DJANGO_ID: force_unicode(obj.pk),
        }

        for field_name, field in self.fields.items():
            # Use the possibly overridden name, which will default to the
            # variable name of the field.
            self.prepared_data[field.index_fieldname] = field.prepare(obj)

            if hasattr(self, "prepare_%s" % field_name):
                value = getattr(self, "prepare_%s" % field_name)(obj)
                self.prepared_data[field.index_fieldname] = value

        return self.prepared_data

    def full_prepare(self, obj):
        self.prepared_data = self.prepare(obj)

        for field_name, field in self.fields.items():
            # Duplicate data for faceted fields.
            if getattr(field, 'facet_for', None):
                source_field_name = self.fields[field.facet_for].index_fieldname

                # If there's data there, leave it alone. Otherwise, populate it
                # with whatever the related field has.
                if self.prepared_data[field_name] is None and source_field_name in self.prepared_data:
                    self.prepared_data[field.index_fieldname] = self.prepared_data[source_field_name]

            # Remove any fields that lack a value and are ``null=True``.
            if field.null is True:
                if self.prepared_data[field.index_fieldname] is None:
                    del(self.prepared_data[field.index_fieldname])

        return self.prepared_data

    def get_content_field(self):
        """Returns the field that supplies the primary document to be indexed."""
        for field_name, field in self.fields.items():
            if field.document is True:
                return field.index_fieldname

    def get_field_weights(self):
        """Returns a dict of fields with weight values"""
        weights = {}
        for field_name, field in self.fields.items():
            if field.boost:
                weights[field_name] = field.boost
        return weights

    def _get_backend(self, using):
        if using is None:
            try:
                using = connection_router.for_write(index=self)[0]
            except IndexError:
                # There's no backend to handle it. Bomb out.
                return None

        return connections[using].get_backend()

    def update(self, using=None):
        """
        Updates the entire index.

        If ``using`` is provided, it specifies which connection should be
        used. Default relies on the routers to decide which backend should
        be used.
        """
        backend = self._get_backend(using)

        if backend is not None:
            backend.update(self, self.index_queryset())

    def update_object(self, instance, using=None, **kwargs):
        """
        Update the index for a single object. Attached to the class's
        post-save hook.

        If ``using`` is provided, it specifies which connection should be
        used. Default relies on the routers to decide which backend should
        be used.
        """
        # Check to make sure we want to index this first.
        if self.should_update(instance, **kwargs):
            backend = self._get_backend(using)

            if backend is not None:
                backend.update(self, [instance])

    def remove_object(self, instance, using=None, **kwargs):
        """
        Remove an object from the index. Attached to the class's
        post-delete hook.

        If ``using`` is provided, it specifies which connection should be
        used. Default relies on the routers to decide which backend should
        be used.
        """
        backend = self._get_backend(using)

        if backend is not None:
            backend.remove(instance)

    def clear(self, using=None):
        """
        Clears the entire index.

        If ``using`` is provided, it specifies which connection should be
        used. Default relies on the routers to decide which backend should
        be used.
        """
        backend = self._get_backend(using)

        if backend is not None:
            backend.clear(models=[self.get_model()])

    def reindex(self, using=None):
        """
        Completely clear the index for this model and rebuild it.

        If ``using`` is provided, it specifies which connection should be
        used. Default relies on the routers to decide which backend should
        be used.
        """
        self.clear(using=using)
        self.update(using=using)

    def get_updated_field(self):
        """
        Get the field name that represents the updated date for the model.

        If specified, this is used by the reindex command to filter out results
        from the QuerySet, enabling you to reindex only recent records. This
        method should either return None (reindex everything always) or a
        string of the Model's DateField/DateTimeField name.
        """
        return None

    def should_update(self, instance, **kwargs):
        """
        Determine if an object should be updated in the index.

        It's useful to override this when an object may save frequently and
        cause excessive reindexing. You should check conditions on the instance
        and return False if it is not to be indexed.

        By default, returns True (always reindex).
        """
        return True

    def load_all_queryset(self):
        """
        Provides the ability to override how objects get loaded in conjunction
        with ``SearchQuerySet.load_all``.

        This is useful for post-processing the results from the query, enabling
        things like adding ``select_related`` or filtering certain data.

        By default, returns ``all()`` on the model's default manager.
        """
        return self.get_model()._default_manager.all()


class BasicSearchIndex(SearchIndex):
    text = CharField(document=True, use_template=True)


# End SearchIndexes
# Begin ModelSearchIndexes


def index_field_from_django_field(f, default=CharField):
    """
    Returns the Haystack field type that would likely be associated with each
    Django type.
    """
    result = default

    if f.get_internal_type() in ('DateField', 'DateTimeField'):
        result = DateTimeField
    elif f.get_internal_type() in ('BooleanField', 'NullBooleanField'):
        result = BooleanField
    elif f.get_internal_type() in ('CommaSeparatedIntegerField',):
        result = MultiValueField
    elif f.get_internal_type() in ('DecimalField', 'FloatField'):
        result = FloatField
    elif f.get_internal_type() in ('IntegerField', 'PositiveIntegerField', 'PositiveSmallIntegerField', 'SmallIntegerField'):
        result = IntegerField

    return result


class ModelSearchIndex(SearchIndex):
    """
    Introspects the model assigned to it and generates a `SearchIndex` based on
    the fields of that model.

    In addition, it adds a `text` field that is the `document=True` field and
    has `use_template=True` option set, just like the `BasicSearchIndex`.

    Usage of this class might result in inferior `SearchIndex` objects, which
    can directly affect your search results. Use this to establish basic
    functionality and move to custom `SearchIndex` objects for better control.

    At this time, it does not handle related fields.
    """
    text = CharField(document=True, use_template=True)
    # list of reserved field names
    fields_to_skip = (ID, DJANGO_CT, DJANGO_ID, 'content', 'text')

    def __init__(self, extra_field_kwargs=None):
        self.model = None

        self.prepared_data = None
        content_fields = []
        self.extra_field_kwargs = extra_field_kwargs or {}

        # Introspect the model, adding/removing fields as needed.
        # Adds/Excludes should happen only if the fields are not already
        # defined in `self.fields`.
        self._meta = getattr(self, 'Meta', None)

        if self._meta:
            self.model = getattr(self._meta, 'model', None)
            fields = getattr(self._meta, 'fields', [])
            excludes = getattr(self._meta, 'excludes', [])

            # Add in the new fields.
            self.fields.update(self.get_fields(fields, excludes))

        for field_name, field in self.fields.items():
            if field.document is True:
                content_fields.append(field_name)

        if not len(content_fields) == 1:
            raise SearchFieldError("The index '%s' must have one (and only one) SearchField with document=True." % self.__class__.__name__)

    def should_skip_field(self, field):
        """
        Given a Django model field, return if it should be included in the
        contributed SearchFields.
        """
        # Skip fields in skip list
        if field.name in self.fields_to_skip:
            return True

        # Ignore certain fields (AutoField, related fields).
        if field.primary_key or getattr(field, 'rel'):
            return True

        return False

    def get_model(self):
        return self.model

    def get_index_fieldname(self, f):
        """
        Given a Django field, return the appropriate index fieldname.
        """
        return f.name

    def get_fields(self, fields=None, excludes=None):
        """
        Given any explicit fields to include and fields to exclude, add
        additional fields based on the associated model.
        """
        final_fields = {}
        fields = fields or []
        excludes = excludes or []

        for f in self.model._meta.fields:
            # If the field name is already present, skip
            if f.name in self.fields:
                continue

            # If field is not present in explicit field listing, skip
            if fields and f.name not in fields:
                continue

            # If field is in exclude list, skip
            if excludes and f.name in excludes:
                continue

            if self.should_skip_field(f):
                continue

            index_field_class = index_field_from_django_field(f)

            kwargs = copy.copy(self.extra_field_kwargs)
            kwargs.update({
                'model_attr': f.name,
            })

            if f.null is True:
                kwargs['null'] = True

            if f.has_default():
                kwargs['default'] = f.default

            final_fields[f.name] = index_field_class(**kwargs)
            final_fields[f.name].set_instance_name(self.get_index_fieldname(f))

        return final_fields
