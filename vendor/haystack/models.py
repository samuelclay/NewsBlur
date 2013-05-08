# "Hey, Django! Look at me, I'm an app! For Serious!"
from django.conf import settings
from django.core.exceptions import ObjectDoesNotExist
from django.db import models
from django.utils.encoding import force_unicode
from django.utils.text import capfirst
from haystack.exceptions import NotHandled, SpatialError
from haystack.utils import log as logging

try:
    from geopy import distance as geopy_distance
except ImportError:
    geopy_distance = None


# Not a Django model, but tightly tied to them and there doesn't seem to be a
# better spot in the tree.
class SearchResult(object):
    """
    A single search result. The actual object is loaded lazily by accessing
    object; until then this object only stores the model, pk, and score.

    Note that iterating over SearchResults and getting the object for each
    result will do O(N) database queries, which may not fit your needs for
    performance.
    """
    def __init__(self, app_label, model_name, pk, score, **kwargs):
        self.app_label, self.model_name = app_label, model_name
        self.pk = pk
        self.score = score
        self._object = None
        self._model = None
        self._verbose_name = None
        self._additional_fields = []
        self._point_of_origin = kwargs.pop('_point_of_origin', None)
        self._distance = kwargs.pop('_distance', None)
        self.stored_fields = None
        self.log = self._get_log()

        for key, value in kwargs.items():
            if not key in self.__dict__:
                self.__dict__[key] = value
                self._additional_fields.append(key)

    def _get_log(self):
        return logging.getLogger('haystack')

    def __repr__(self):
        return "<SearchResult: %s.%s (pk=%r)>" % (self.app_label, self.model_name, self.pk)

    def __unicode__(self):
        return force_unicode(self.__repr__())

    def __getattr__(self, attr):
        if attr == '__getnewargs__':
            raise AttributeError

        return self.__dict__.get(attr, None)

    def _get_searchindex(self):
        from haystack import connections
        return connections['default'].get_unified_index().get_index(self.model)

    searchindex = property(_get_searchindex)

    def _get_object(self):
        if self._object is None:
            if self.model is None:
                self.log.error("Model could not be found for SearchResult '%s'.", self)
                return None

            try:
                try:
                    self._object = self.searchindex.read_queryset().get(pk=self.pk)
                except NotHandled:
                    self.log.warning("Model '%s.%s' not handled by the routers.", self.app_label, self.model_name)
                    # Revert to old behaviour
                    self._object = self.model._default_manager.get(pk=self.pk)
            except ObjectDoesNotExist:
                self.log.error("Object could not be found in database for SearchResult '%s'.", self)
                self._object = None

        return self._object

    def _set_object(self, obj):
        self._object = obj

    object = property(_get_object, _set_object)

    def _get_model(self):
        if self._model is None:
            self._model = models.get_model(self.app_label, self.model_name)

        return self._model

    def _set_model(self, obj):
        self._model = obj

    model = property(_get_model, _set_model)

    def _get_distance(self):
        from haystack.utils.geo import Distance

        if self._distance is None:
            # We didn't get it from the backend & we haven't tried calculating
            # it yet. Check if geopy is available to do it the "slow" way
            # (even though slow meant 100 distance calculations in 0.004 seconds
            # in my testing).
            if geopy_distance is None:
                raise SpatialError("The backend doesn't have 'DISTANCE_AVAILABLE' enabled & the 'geopy' library could not be imported, so distance information is not available.")

            if not self._point_of_origin:
                raise SpatialError("The original point is not available.")

            if not hasattr(self, self._point_of_origin['field']):
                raise SpatialError("The field '%s' was not included in search results, so the distance could not be calculated." % self._point_of_origin['field'])

            po_lng, po_lat = self._point_of_origin['point'].get_coords()
            location_field = getattr(self, self._point_of_origin['field'])

            if location_field is None:
                return None

            lf_lng, lf_lat  = location_field.get_coords()
            self._distance = Distance(km=geopy_distance.distance((po_lat, po_lng), (lf_lat, lf_lng)).km)

        # We've either already calculated it or the backend returned it, so
        # let's use that.
        return self._distance

    def _set_distance(self, dist):
        self._distance = dist

    distance = property(_get_distance, _set_distance)

    def _get_verbose_name(self):
        if self.model is None:
            self.log.error("Model could not be found for SearchResult '%s'.", self)
            return u''

        return force_unicode(capfirst(self.model._meta.verbose_name))

    verbose_name = property(_get_verbose_name)

    def _get_verbose_name_plural(self):
        if self.model is None:
            self.log.error("Model could not be found for SearchResult '%s'.", self)
            return u''

        return force_unicode(capfirst(self.model._meta.verbose_name_plural))

    verbose_name_plural = property(_get_verbose_name_plural)

    def content_type(self):
        """Returns the content type for the result's model instance."""
        if self.model is None:
            self.log.error("Model could not be found for SearchResult '%s'.", self)
            return u''

        return unicode(self.model._meta)

    def get_additional_fields(self):
        """
        Returns a dictionary of all of the fields from the raw result.

        Useful for serializing results. Only returns what was seen from the
        search engine, so it may have extra fields Haystack's indexes aren't
        aware of.
        """
        additional_fields = {}

        for fieldname in self._additional_fields:
            additional_fields[fieldname] = getattr(self, fieldname)

        return additional_fields

    def get_stored_fields(self):
        """
        Returns a dictionary of all of the stored fields from the SearchIndex.

        Useful for serializing results. Only returns the fields Haystack's
        indexes are aware of as being 'stored'.
        """
        if self._stored_fields is None:
            from haystack import connections
            from haystack.exceptions import NotHandled

            try:
                index = connections['default'].get_unified_index().get_index(self.model)
            except NotHandled:
                # Not found? Return nothing.
                return {}

            self._stored_fields = {}

            # Iterate through the index's fields, pulling out the fields that
            # are stored.
            for fieldname, field in index.fields.items():
                if field.stored is True:
                    self._stored_fields[fieldname] = getattr(self, fieldname, u'')

        return self._stored_fields

    def __getstate__(self):
        """
        Returns a dictionary representing the ``SearchResult`` in order to
        make it pickleable.
        """
        # The ``log`` is excluded because, under the hood, ``logging`` uses
        # ``threading.Lock``, which doesn't pickle well.
        ret_dict = self.__dict__.copy()
        del(ret_dict['log'])
        return ret_dict

    def __setstate__(self, data_dict):
        """
        Updates the object's attributes according to data passed by pickle.
        """
        self.__dict__.update(data_dict)
        self.log = self._get_log()


def reload_indexes(sender, *args, **kwargs):
    from haystack import connections

    for conn in connections.all():
        ui = conn.get_unified_index()
        # Note: Unlike above, we're resetting the ``UnifiedIndex`` here.
        # Thi gives us a clean slate.
        ui.reset()
