import operator
import warnings
from haystack import connections, connection_router
from haystack.backends import SQ
from haystack.constants import REPR_OUTPUT_SIZE, ITERATOR_LOAD_PER_QUERY, DEFAULT_OPERATOR
from haystack.exceptions import NotHandled
from haystack.inputs import Raw, Clean, AutoQuery
from haystack.utils import log as logging


class SearchQuerySet(object):
    """
    Provides a way to specify search parameters and lazily load results.

    Supports chaining (a la QuerySet) to narrow the search.
    """
    def __init__(self, using=None, query=None):
        # ``_using`` should only ever be a value other than ``None`` if it's
        # been forced with the ``.using`` method.
        self._using = using
        self.query = None
        self._determine_backend()

        # If ``query`` is present, it should override even what the routers
        # think.
        if query is not None:
            self.query = query

        self._result_cache = []
        self._result_count = None
        self._cache_full = False
        self._load_all = False
        self._ignored_result_count = 0
        self.log = logging.getLogger('haystack')

    def _determine_backend(self):
        from haystack import connections
        # A backend has been manually selected. Use it instead.
        if self._using is not None:
            self.query = connections[self._using].get_query()
            return

        # No backend, so rely on the routers to figure out what's right.
        hints = {}

        if self.query:
            hints['models'] = self.query.models

        backend_alias = connection_router.for_read(**hints)

        if isinstance(backend_alias, (list, tuple)) and len(backend_alias):
            # We can only effectively read from one engine.
            backend_alias = backend_alias[0]

        # The ``SearchQuery`` might swap itself out for a different variant
        # here.
        if self.query:
            self.query = self.query.using(backend_alias)
        else:
            self.query = connections[backend_alias].get_query()

    def __getstate__(self):
        """
        For pickling.
        """
        len(self)
        obj_dict = self.__dict__.copy()
        obj_dict['_iter'] = None
        obj_dict['log'] = None
        return obj_dict

    def __setstate__(self, data_dict):
        """
        For unpickling.
        """
        self.__dict__ = data_dict
        self.log = logging.getLogger('haystack')

    def __repr__(self):
        data = list(self[:REPR_OUTPUT_SIZE])

        if len(self) > REPR_OUTPUT_SIZE:
            data[-1] = "...(remaining elements truncated)..."

        return repr(data)

    def __len__(self):
        if not self._result_count:
            self._result_count = self.query.get_count()

            # Some backends give weird, false-y values here. Convert to zero.
            if not self._result_count:
                self._result_count = 0

        # This needs to return the actual number of hits, not what's in the cache.
        return self._result_count - self._ignored_result_count

    def __iter__(self):
        if self._cache_is_full():
            # We've got a fully populated cache. Let Python do the hard work.
            return iter(self._result_cache)

        return self._manual_iter()

    def __and__(self, other):
        if isinstance(other, EmptySearchQuerySet):
            return other._clone()
        combined = self._clone()
        combined.query.combine(other.query, SQ.AND)
        return combined

    def __or__(self, other):
        combined = self._clone()
        if isinstance(other, EmptySearchQuerySet):
            return combined
        combined.query.combine(other.query, SQ.OR)
        return combined

    def _cache_is_full(self):
        if not self.query.has_run():
            return False

        if len(self) <= 0:
            return True

        try:
            self._result_cache.index(None)
            return False
        except ValueError:
            # No ``None``s found in the results. Check the length of the cache.
            return len(self._result_cache) > 0

    def _manual_iter(self):
        # If we're here, our cache isn't fully populated.
        # For efficiency, fill the cache as we go if we run out of results.
        # Also, this can't be part of the __iter__ method due to Python's rules
        # about generator functions.
        current_position = 0
        current_cache_max = 0

        while True:
            if len(self._result_cache) > 0:
                try:
                    current_cache_max = self._result_cache.index(None)
                except ValueError:
                    current_cache_max = len(self._result_cache)

            while current_position < current_cache_max:
                yield self._result_cache[current_position]
                current_position += 1

            if self._cache_is_full():
                raise StopIteration

            # We've run out of results and haven't hit our limit.
            # Fill more of the cache.
            if not self._fill_cache(current_position, current_position + ITERATOR_LOAD_PER_QUERY):
                raise StopIteration

    def _fill_cache(self, start, end, **kwargs):
        # Tell the query where to start from and how many we'd like.
        self.query._reset()
        self.query.set_limits(start, end)
        results = self.query.get_results(**kwargs)

        if results == None or len(results) == 0:
            return False

        # Setup the full cache now that we know how many results there are.
        # We need the ``None``s as placeholders to know what parts of the
        # cache we have/haven't filled.
        # Using ``None`` like this takes up very little memory. In testing,
        # an array of 100,000 ``None``s consumed less than .5 Mb, which ought
        # to be an acceptable loss for consistent and more efficient caching.
        if len(self._result_cache) == 0:
            self._result_cache = [None for i in xrange(self.query.get_count())]

        if start is None:
            start = 0

        if end is None:
            end = self.query.get_count()

        to_cache = self.post_process_results(results)

        # Assign by slice.
        self._result_cache[start:start + len(to_cache)] = to_cache
        return True

    def post_process_results(self, results):
        to_cache = []

        # Check if we wish to load all objects.
        if self._load_all:
            original_results = []
            models_pks = {}
            loaded_objects = {}

            # Remember the search position for each result so we don't have to resort later.
            for result in results:
                original_results.append(result)
                models_pks.setdefault(result.model, []).append(result.pk)

            # Load the objects for each model in turn.
            for model in models_pks:
                try:
                    ui = connections[self.query._using].get_unified_index()
                    index = ui.get_index(model)
                    objects = index.read_queryset(using=self.query._using)
                    loaded_objects[model] = objects.in_bulk(models_pks[model])
                except NotHandled:
                    self.log.warning("Model '%s.%s' not handled by the routers.", self.app_label, self.model_name)
                    # Revert to old behaviour
                    loaded_objects[model] = model._default_manager.in_bulk(models_pks[model])

        for result in results:
            if self._load_all:
                # We have to deal with integer keys being cast from strings
                model_objects = loaded_objects.get(result.model, {})
                if not result.pk in model_objects:
                    try:
                        result.pk = int(result.pk)
                    except ValueError:
                        pass
                try:
                    result._object = model_objects[result.pk]
                except KeyError:
                    # The object was either deleted since we indexed or should
                    # be ignored; fail silently.
                    self._ignored_result_count += 1
                    continue

            to_cache.append(result)

        return to_cache

    def __getitem__(self, k):
        """
        Retrieves an item or slice from the set of results.
        """
        if not isinstance(k, (slice, int, long)):
            raise TypeError
        assert ((not isinstance(k, slice) and (k >= 0))
                or (isinstance(k, slice) and (k.start is None or k.start >= 0)
                    and (k.stop is None or k.stop >= 0))), \
                "Negative indexing is not supported."

        # Remember if it's a slice or not. We're going to treat everything as
        # a slice to simply the logic and will `.pop()` at the end as needed.
        if isinstance(k, slice):
            is_slice = True
            start = k.start

            if k.stop is not None:
                bound = int(k.stop)
            else:
                bound = None
        else:
            is_slice = False
            start = k
            bound = k + 1

        # We need check to see if we need to populate more of the cache.
        if len(self._result_cache) <= 0 or (None in self._result_cache[start:bound] and not self._cache_is_full()):
            try:
                self._fill_cache(start, bound)
            except StopIteration:
                # There's nothing left, even though the bound is higher.
                pass

        # Cache should be full enough for our needs.
        if is_slice:
            return self._result_cache[start:bound]
        else:
            return self._result_cache[start]

    # Methods that return a SearchQuerySet.
    def all(self):
        """Returns all results for the query."""
        return self._clone()

    def none(self):
        """Returns an empty result list for the query."""
        return self._clone(klass=EmptySearchQuerySet)

    def filter(self, *args, **kwargs):
        """Narrows the search based on certain attributes and the default operator."""
        if DEFAULT_OPERATOR == 'OR':
            return self.filter_or(*args, **kwargs)
        else:
            return self.filter_and(*args, **kwargs)

    def exclude(self, *args, **kwargs):
        """Narrows the search by ensuring certain attributes are not included."""
        clone = self._clone()
        clone.query.add_filter(~SQ(*args, **kwargs))
        return clone

    def filter_and(self, *args, **kwargs):
        """Narrows the search by looking for (and including) certain attributes."""
        clone = self._clone()
        clone.query.add_filter(SQ(*args, **kwargs))
        return clone

    def filter_or(self, *args, **kwargs):
        """Narrows the search by ensuring certain attributes are not included."""
        clone = self._clone()
        clone.query.add_filter(SQ(*args, **kwargs), use_or=True)
        return clone

    def order_by(self, *args):
        """Alters the order in which the results should appear."""
        clone = self._clone()

        for field in args:
            clone.query.add_order_by(field)

        return clone

    def order_by_distance(self, **kwargs):
        """Alters the order in which the results should appear."""
        clone = self._clone()
        clone.query.add_order_by_distance(**kwargs)
        return clone

    def highlight(self):
        """Adds highlighting to the results."""
        clone = self._clone()
        clone.query.add_highlight()
        return clone

    def models(self, *models):
        """Accepts an arbitrary number of Model classes to include in the search."""
        clone = self._clone()

        for model in models:
            if not model in connections[self.query._using].get_unified_index().get_indexed_models():
                warnings.warn('The model %r is not registered for search.' % model)

            clone.query.add_model(model)

        return clone

    def result_class(self, klass):
        """
        Allows specifying a different class to use for results.

        Overrides any previous usages. If ``None`` is provided, Haystack will
        revert back to the default ``SearchResult`` object.
        """
        clone = self._clone()
        clone.query.set_result_class(klass)
        return clone

    def boost(self, term, boost):
        """Boosts a certain aspect of the query."""
        clone = self._clone()
        clone.query.add_boost(term, boost)
        return clone

    def facet(self, field, **options):
        """Adds faceting to a query for the provided field."""
        clone = self._clone()
        clone.query.add_field_facet(field, **options)
        return clone

    def within(self, field, point_1, point_2):
        """Spatial: Adds a bounding box search to the query."""
        clone = self._clone()
        clone.query.add_within(field, point_1, point_2)
        return clone

    def dwithin(self, field, point, distance):
        """Spatial: Adds a distance-based search to the query."""
        clone = self._clone()
        clone.query.add_dwithin(field, point, distance)
        return clone

    def distance(self, field, point):
        """
        Spatial: Denotes results must have distance measurements from the
        provided point.
        """
        clone = self._clone()
        clone.query.add_distance(field, point)
        return clone

    def date_facet(self, field, start_date, end_date, gap_by, gap_amount=1):
        """Adds faceting to a query for the provided field by date."""
        clone = self._clone()
        clone.query.add_date_facet(field, start_date, end_date, gap_by, gap_amount=gap_amount)
        return clone

    def query_facet(self, field, query):
        """Adds faceting to a query for the provided field with a custom query."""
        clone = self._clone()
        clone.query.add_query_facet(field, query)
        return clone

    def narrow(self, query):
        """Pushes existing facet choices into the search."""
        clone = self._clone()
        clone.query.add_narrow_query(query)
        return clone

    def raw_search(self, query_string, **kwargs):
        """Passes a raw query directly to the backend."""
        return self.filter(content=Raw(query_string, **kwargs))

    def load_all(self):
        """Efficiently populates the objects in the search results."""
        clone = self._clone()
        clone._load_all = True
        return clone

    def auto_query(self, query_string, fieldname='content'):
        """
        Performs a best guess constructing the search query.

        This method is somewhat naive but works well enough for the simple,
        common cases.
        """
        kwargs = {
            fieldname: AutoQuery(query_string)
        }
        return self.filter(**kwargs)

    def autocomplete(self, **kwargs):
        """
        A shortcut method to perform an autocomplete search.

        Must be run against fields that are either ``NgramField`` or
        ``EdgeNgramField``.
        """
        clone = self._clone()
        query_bits = []

        for field_name, query in kwargs.items():
            for word in query.split(' '):
                bit = clone.query.clean(word.strip())
                kwargs = {
                    field_name: bit,
                }
                query_bits.append(SQ(**kwargs))

        return clone.filter(reduce(operator.__and__, query_bits))

    def using(self, connection_name):
        """
        Allows switching which connection the ``SearchQuerySet`` uses to
        search in.
        """
        clone = self._clone()
        clone.query = self.query.using(connection_name)
        clone._using = connection_name
        return clone

    # Methods that do not return a SearchQuerySet.

    def count(self):
        """Returns the total number of matching results."""
        return len(self)

    def best_match(self):
        """Returns the best/top search result that matches the query."""
        return self[0]

    def latest(self, date_field):
        """Returns the most recent search result that matches the query."""
        clone = self._clone()
        clone.query.clear_order_by()
        clone.query.add_order_by("-%s" % date_field)
        return clone.best_match()

    def more_like_this(self, model_instance):
        """Finds similar results to the object passed in."""
        clone = self._clone()
        clone.query.more_like_this(model_instance)
        return clone

    def facet_counts(self):
        """
        Returns the facet counts found by the query.

        This will cause the query to execute and should generally be used when
        presenting the data.
        """
        if self.query.has_run():
            return self.query.get_facet_counts()
        else:
            clone = self._clone()
            return clone.query.get_facet_counts()

    def spelling_suggestion(self, preferred_query=None):
        """
        Returns the spelling suggestion found by the query.

        To work, you must set ``INCLUDE_SPELLING`` within your connection's
        settings dictionary to ``True``. Otherwise, ``None`` will be returned.

        This will cause the query to execute and should generally be used when
        presenting the data.
        """
        if self.query.has_run():
            return self.query.get_spelling_suggestion(preferred_query)
        else:
            clone = self._clone()
            return clone.query.get_spelling_suggestion(preferred_query)

    def values(self, *fields):
        """
        Returns a list of dictionaries, each containing the key/value pairs for
        the result, exactly like Django's ``ValuesQuerySet``.
        """
        qs = self._clone(klass=ValuesSearchQuerySet)
        qs._fields.extend(fields)
        return qs

    def values_list(self, *fields, **kwargs):
        """
        Returns a list of field values as tuples, exactly like Django's
        ``QuerySet.values``.

        Optionally accepts a ``flat=True`` kwarg, which in the case of a
        single field being provided, will return a flat list of that field
        rather than a list of tuples.
        """
        flat = kwargs.pop("flat", False)

        if flat and len(fields) > 1:
            raise TypeError("'flat' is not valid when values_list is called with more than one field.")

        qs = self._clone(klass=ValuesListSearchQuerySet)
        qs._fields.extend(fields)
        qs._flat = flat
        return qs

    # Utility methods.

    def _clone(self, klass=None):
        if klass is None:
            klass = self.__class__

        query = self.query._clone()
        clone = klass(query=query)
        clone._load_all = self._load_all
        return clone


class EmptySearchQuerySet(SearchQuerySet):
    """
    A stubbed SearchQuerySet that behaves as normal but always returns no
    results.
    """
    def __len__(self):
        return 0

    def _cache_is_full(self):
        # Pretend the cache is always full with no results.
        return True

    def _clone(self, klass=None):
        clone = super(EmptySearchQuerySet, self)._clone(klass=klass)
        clone._result_cache = []
        return clone

    def _fill_cache(self, start, end):
        return False

    def facet_counts(self):
        return {}


class ValuesListSearchQuerySet(SearchQuerySet):
    """
    A ``SearchQuerySet`` which returns a list of field values as tuples, exactly
    like Django's ``ValuesListQuerySet``.
    """
    def __init__(self, *args, **kwargs):
        super(ValuesListSearchQuerySet, self).__init__(*args, **kwargs)
        self._flat = False
        self._fields = []

        # Removing this dependency would require refactoring much of the backend
        # code (_process_results, etc.) and these aren't large enough to make it
        # an immediate priority:
        self._internal_fields = ['id', 'django_ct', 'django_id', 'score']

    def _clone(self, klass=None):
        clone = super(ValuesListSearchQuerySet, self)._clone(klass=klass)
        clone._fields = self._fields
        clone._flat = self._flat
        return clone

    def _fill_cache(self, start, end):
        query_fields = set(self._internal_fields)
        query_fields.update(self._fields)
        kwargs = {
            'fields': query_fields
        }
        return super(ValuesListSearchQuerySet, self)._fill_cache(start, end, **kwargs)

    def post_process_results(self, results):
        to_cache = []

        if self._flat:
            accum = to_cache.extend
        else:
            accum = to_cache.append

        for result in results:
            accum([getattr(result, i, None) for i in self._fields])

        return to_cache


class ValuesSearchQuerySet(ValuesListSearchQuerySet):
    """
    A ``SearchQuerySet`` which returns a list of dictionaries, each containing
    the key/value pairs for the result, exactly like Django's
    ``ValuesQuerySet``.
    """
    def _fill_cache(self, start, end):
        query_fields = set(self._internal_fields)
        query_fields.update(self._fields)
        kwargs = {
            'fields': query_fields
        }
        return super(ValuesListSearchQuerySet, self)._fill_cache(start, end, **kwargs)

    def post_process_results(self, results):
        to_cache = []

        for result in results:
            to_cache.append(dict((i, getattr(result, i, None)) for i in self._fields))

        return to_cache


class RelatedSearchQuerySet(SearchQuerySet):
    """
    A variant of the SearchQuerySet that can handle `load_all_queryset`s.

    This is predominantly different in the `_fill_cache` method, as it is
    far less efficient but needs to fill the cache before it to maintain
    consistency.
    """
    _load_all_querysets = {}
    _result_cache = []

    def _cache_is_full(self):
        return len(self._result_cache) >= len(self)

    def _manual_iter(self):
        # If we're here, our cache isn't fully populated.
        # For efficiency, fill the cache as we go if we run out of results.
        # Also, this can't be part of the __iter__ method due to Python's rules
        # about generator functions.
        current_position = 0
        current_cache_max = 0

        while True:
            current_cache_max = len(self._result_cache)

            while current_position < current_cache_max:
                yield self._result_cache[current_position]
                current_position += 1

            if self._cache_is_full():
                raise StopIteration

            # We've run out of results and haven't hit our limit.
            # Fill more of the cache.
            start = current_position + self._ignored_result_count

            if not self._fill_cache(start, start + ITERATOR_LOAD_PER_QUERY):
                raise StopIteration

    def _fill_cache(self, start, end):
        # Tell the query where to start from and how many we'd like.
        self.query._reset()
        self.query.set_limits(start, end)
        results = self.query.get_results()

        if len(results) == 0:
            return False

        if start is None:
            start = 0

        if end is None:
            end = self.query.get_count()

        # Check if we wish to load all objects.
        if self._load_all:
            original_results = []
            models_pks = {}
            loaded_objects = {}

            # Remember the search position for each result so we don't have to resort later.
            for result in results:
                original_results.append(result)
                models_pks.setdefault(result.model, []).append(result.pk)

            # Load the objects for each model in turn.
            for model in models_pks:
                if model in self._load_all_querysets:
                    # Use the overriding queryset.
                    loaded_objects[model] = self._load_all_querysets[model].in_bulk(models_pks[model])
                else:
                    # Check the SearchIndex for the model for an override.
                    try:
                        index = connections[self.query._using].get_unified_index().get_index(model)
                        qs = index.load_all_queryset()
                        loaded_objects[model] = qs.in_bulk(models_pks[model])
                    except NotHandled:
                        # The model returned doesn't seem to be handled by the
                        # routers. We should silently fail and populate
                        # nothing for those objects.
                        loaded_objects[model] = []

        if len(results) + len(self._result_cache) < len(self) and len(results) < ITERATOR_LOAD_PER_QUERY:
            self._ignored_result_count += ITERATOR_LOAD_PER_QUERY - len(results)

        for result in results:
            if self._load_all:
                # We have to deal with integer keys being cast from strings; if this
                # fails we've got a character pk.
                try:
                    result.pk = int(result.pk)
                except ValueError:
                    pass
                try:
                    result._object = loaded_objects[result.model][result.pk]
                except (KeyError, IndexError):
                    # The object was either deleted since we indexed or should
                    # be ignored; fail silently.
                    self._ignored_result_count += 1
                    continue

            self._result_cache.append(result)

        return True

    def __getitem__(self, k):
        """
        Retrieves an item or slice from the set of results.
        """
        if not isinstance(k, (slice, int, long)):
            raise TypeError
        assert ((not isinstance(k, slice) and (k >= 0))
                or (isinstance(k, slice) and (k.start is None or k.start >= 0)
                    and (k.stop is None or k.stop >= 0))), \
                "Negative indexing is not supported."

        # Remember if it's a slice or not. We're going to treat everything as
        # a slice to simply the logic and will `.pop()` at the end as needed.
        if isinstance(k, slice):
            is_slice = True
            start = k.start

            if k.stop is not None:
                bound = int(k.stop)
            else:
                bound = None
        else:
            is_slice = False
            start = k
            bound = k + 1

        # We need check to see if we need to populate more of the cache.
        if len(self._result_cache) <= 0 or not self._cache_is_full():
            try:
                while len(self._result_cache) < bound and not self._cache_is_full():
                    current_max = len(self._result_cache) + self._ignored_result_count
                    self._fill_cache(current_max, current_max + ITERATOR_LOAD_PER_QUERY)
            except StopIteration:
                # There's nothing left, even though the bound is higher.
                pass

        # Cache should be full enough for our needs.
        if is_slice:
            return self._result_cache[start:bound]
        else:
            return self._result_cache[start]

    def load_all_queryset(self, model, queryset):
        """
        Allows for specifying a custom ``QuerySet`` that changes how ``load_all``
        will fetch records for the provided model.

        This is useful for post-processing the results from the query, enabling
        things like adding ``select_related`` or filtering certain data.
        """
        clone = self._clone()
        clone._load_all_querysets[model] = queryset
        return clone

    def _clone(self, klass=None):
        if klass is None:
            klass = self.__class__

        query = self.query._clone()
        clone = klass(query=query)
        clone._load_all = self._load_all
        clone._load_all_querysets = self._load_all_querysets
        return clone
