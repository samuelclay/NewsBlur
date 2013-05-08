# -*- coding: utf-8 -*-
from copy import deepcopy
from time import time
from django.conf import settings
from django.db.models import Q
from django.db.models.base import ModelBase
from django.utils import tree
from django.utils.encoding import force_unicode
from haystack.constants import VALID_FILTERS, FILTER_SEPARATOR, DEFAULT_ALIAS
from haystack.exceptions import MoreLikeThisError, FacetingError
from haystack.models import SearchResult
from haystack.utils.loading import UnifiedIndex

VALID_GAPS = ['year', 'month', 'day', 'hour', 'minute', 'second']


def log_query(func):
    """
    A decorator for pseudo-logging search queries. Used in the ``SearchBackend``
    to wrap the ``search`` method.
    """
    def wrapper(obj, query_string, *args, **kwargs):
        start = time()

        try:
            return func(obj, query_string, *args, **kwargs)
        finally:
            stop = time()

            if settings.DEBUG:
                from haystack import connections
                connections[obj.connection_alias].queries.append({
                    'query_string': query_string,
                    'additional_args': args,
                    'additional_kwargs': kwargs,
                    'time': "%.3f" % (stop - start),
                    'start': start,
                    'stop': stop,
                })

    return wrapper


class EmptyResults(object):
    hits = 0
    docs = []

    def __len__(self):
        return 0

    def __getitem__(self, k):
        if isinstance(k, slice):
            return []
        else:
            raise IndexError("It's not here.")


class BaseSearchBackend(object):
    """
    Abstract search engine base class.
    """
    # Backends should include their own reserved words/characters.
    RESERVED_WORDS = []
    RESERVED_CHARACTERS = []

    def __init__(self, connection_alias, **connection_options):
        self.connection_alias = connection_alias
        self.timeout = connection_options.get('TIMEOUT', 10)
        self.include_spelling = connection_options.get('INCLUDE_SPELLING', False)
        self.batch_size = connection_options.get('BATCH_SIZE', 1000)
        self.silently_fail = connection_options.get('SILENTLY_FAIL', True)
        self.distance_available = connection_options.get('DISTANCE_AVAILABLE', False)

    def update(self, index, iterable):
        """
        Updates the backend when given a SearchIndex and a collection of
        documents.

        This method MUST be implemented by each backend, as it will be highly
        specific to each one.
        """
        raise NotImplementedError

    def remove(self, obj_or_string):
        """
        Removes a document/object from the backend. Can be either a model
        instance or the identifier (i.e. ``app_name.model_name.id``) in the
        event the object no longer exists.

        This method MUST be implemented by each backend, as it will be highly
        specific to each one.
        """
        raise NotImplementedError

    def clear(self, models=[], commit=True):
        """
        Clears the backend of all documents/objects for a collection of models.

        This method MUST be implemented by each backend, as it will be highly
        specific to each one.
        """
        raise NotImplementedError

    @log_query
    def search(self, query_string, **kwargs):
        """
        Takes a query to search on and returns dictionary.

        The query should be a string that is appropriate syntax for the backend.

        The returned dictionary should contain the keys 'results' and 'hits'.
        The 'results' value should be an iterable of populated SearchResult
        objects. The 'hits' should be an integer count of the number of matched
        results the search backend found.

        This method MUST be implemented by each backend, as it will be highly
        specific to each one.
        """
        raise NotImplementedError

    def build_search_kwargs(self, query_string, sort_by=None, start_offset=0, end_offset=None,
                            fields='', highlight=False, facets=None,
                            date_facets=None, query_facets=None,
                            narrow_queries=None, spelling_query=None,
                            within=None, dwithin=None, distance_point=None,
                            models=None, limit_to_registered_models=None,
                            result_class=None):
        # A convenience method most backends should include in order to make
        # extension easier.
        raise NotImplementedError

    def prep_value(self, value):
        """
        Hook to give the backend a chance to prep an attribute value before
        sending it to the search engine. By default, just force it to unicode.
        """
        return force_unicode(value)

    def more_like_this(self, model_instance, additional_query_string=None, result_class=None):
        """
        Takes a model object and returns results the backend thinks are similar.

        This method MUST be implemented by each backend, as it will be highly
        specific to each one.
        """
        raise NotImplementedError("Subclasses must provide a way to fetch similar record via the 'more_like_this' method if supported by the backend.")

    def extract_file_contents(self, file_obj):
        """
        Hook to allow backends which support rich-content types such as PDF,
        Word, etc. extraction to process the provided file object and return
        the contents for indexing

        Returns None if metadata cannot be extracted; otherwise returns a
        dictionary containing at least two keys:

            :contents:
                        Extracted full-text content, if applicable
            :metadata:
                        key:value pairs of text strings
        """

        raise NotImplementedError("Subclasses must provide a way to extract metadata via the 'extract' method if supported by the backend.")

    def build_schema(self, fields):
        """
        Takes a dictionary of fields and returns schema information.

        This method MUST be implemented by each backend, as it will be highly
        specific to each one.
        """
        raise NotImplementedError("Subclasses must provide a way to build their schema.")

    def build_models_list(self):
        """
        Builds a list of models for searching.

        The ``search`` method should use this and the ``django_ct`` field to
        narrow the results (unless the user indicates not to). This helps ignore
        any results that are not currently handled models and ensures
        consistent caching.
        """
        from haystack import connections
        models = []

        for model in connections[self.connection_alias].get_unified_index().get_indexed_models():
            models.append(u"%s.%s" % (model._meta.app_label, model._meta.module_name))

        return models


# Alias for easy loading within SearchQuery objects.
SearchBackend = BaseSearchBackend


class SearchNode(tree.Node):
    """
    Manages an individual condition within a query.

    Most often, this will be a lookup to ensure that a certain word or phrase
    appears in the documents being indexed. However, it also supports filtering
    types (such as 'lt', 'gt', 'in' and others) for more complex lookups.

    This object creates a tree, with children being a list of either more
    ``SQ`` objects or the expressions/values themselves.
    """
    AND = 'AND'
    OR = 'OR'
    default = AND

    def __repr__(self):
        return '<SQ: %s %s>' % (self.connector, self.as_query_string(self._repr_query_fragment_callback))

    def _repr_query_fragment_callback(self, field, filter_type, value):
        return "%s%s%s=%s" % (field, FILTER_SEPARATOR, filter_type, force_unicode(value).encode('utf8'))

    def as_query_string(self, query_fragment_callback):
        """
        Produces a portion of the search query from the current SQ and its
        children.
        """
        result = []

        for child in self.children:
            if hasattr(child, 'as_query_string'):
                result.append(child.as_query_string(query_fragment_callback))
            else:
                expression, value = child
                field, filter_type = self.split_expression(expression)
                result.append(query_fragment_callback(field, filter_type, value))

        conn = ' %s ' % self.connector
        query_string = conn.join(result)

        if query_string:
            if self.negated:
                query_string = 'NOT (%s)' % query_string
            elif len(self.children) != 1:
                query_string = '(%s)' % query_string

        return query_string

    def split_expression(self, expression):
        """Parses an expression and determines the field and filter type."""
        parts = expression.split(FILTER_SEPARATOR)
        field = parts[0]

        if len(parts) == 1 or parts[-1] not in VALID_FILTERS:
            filter_type = 'contains'
        else:
            filter_type = parts.pop()

        return (field, filter_type)


class SQ(Q, SearchNode):
    """
    Manages an individual condition within a query.

    Most often, this will be a lookup to ensure that a certain word or phrase
    appears in the documents being indexed. However, it also supports filtering
    types (such as 'lt', 'gt', 'in' and others) for more complex lookups.
    """
    pass


class BaseSearchQuery(object):
    """
    A base class for handling the query itself.

    This class acts as an intermediary between the ``SearchQuerySet`` and the
    ``SearchBackend`` itself.

    The ``SearchQuery`` object maintains a tree of ``SQ`` objects. Each ``SQ``
    object supports what field it looks up against, what kind of lookup (i.e.
    the __'s), what value it's looking for, if it's a AND/OR/NOT and tracks
    any children it may have. The ``SearchQuery.build_query`` method starts with
    the root of the tree, building part of the final query at each node until
    the full final query is ready for the ``SearchBackend``.

    Backends should extend this class and provide implementations for
    ``build_query_fragment``, ``clean`` and ``run``. See the ``solr`` backend for an example
    implementation.
    """

    def __init__(self, using=DEFAULT_ALIAS):
        self.query_filter = SearchNode()
        self.order_by = []
        self.models = set()
        self.boost = {}
        self.start_offset = 0
        self.end_offset = None
        self.highlight = False
        self.facets = {}
        self.date_facets = {}
        self.query_facets = []
        self.narrow_queries = set()
        #: If defined, fields should be a list of field names - no other values
        #: will be retrieved so the caller must be careful to include django_ct
        #: and django_id when using code which expects those to be included in
        #: the results
        self.fields = []
        # Geospatial-related information
        self.within = {}
        self.dwithin = {}
        self.distance_point = {}
        # Internal.
        self._raw_query = None
        self._raw_query_params = {}
        self._more_like_this = False
        self._mlt_instance = None
        self._results = None
        self._hit_count = None
        self._facet_counts = None
        self._spelling_suggestion = None
        self.result_class = SearchResult

        from haystack import connections
        self._using = using
        self.backend = connections[self._using].get_backend()

    def __str__(self):
        return self.build_query()

    def __getstate__(self):
        """For pickling."""
        obj_dict = self.__dict__.copy()
        del(obj_dict['backend'])
        return obj_dict

    def __setstate__(self, obj_dict):
        """For unpickling."""
        from haystack import connections
        self.__dict__.update(obj_dict)
        self.backend = connections[self._using].get_backend()

    def has_run(self):
        """Indicates if any query has been been run."""
        return None not in (self._results, self._hit_count)

    def build_params(self, spelling_query=None):
        """Generates a list of params to use when searching."""
        kwargs = {
            'start_offset': self.start_offset,
        }

        if self.order_by:
            kwargs['sort_by'] = self.order_by

        if self.end_offset is not None:
            kwargs['end_offset'] = self.end_offset

        if self.highlight:
            kwargs['highlight'] = self.highlight

        if self.facets:
            kwargs['facets'] = self.facets

        if self.date_facets:
            kwargs['date_facets'] = self.date_facets

        if self.query_facets:
            kwargs['query_facets'] = self.query_facets

        if self.narrow_queries:
            kwargs['narrow_queries'] = self.narrow_queries

        if spelling_query:
            kwargs['spelling_query'] = spelling_query

        if self.boost:
            kwargs['boost'] = self.boost

        if self.within:
            kwargs['within'] = self.within

        if self.dwithin:
            kwargs['dwithin'] = self.dwithin

        if self.distance_point:
            kwargs['distance_point'] = self.distance_point

        if self.result_class:
            kwargs['result_class'] = self.result_class

        if self.fields:
            kwargs['fields'] = self.fields

        if self.models:
            kwargs['models'] = self.models

        return kwargs

    def run(self, spelling_query=None, **kwargs):
        """Builds and executes the query. Returns a list of search results."""
        final_query = self.build_query()
        search_kwargs = self.build_params(spelling_query=spelling_query)

        if kwargs:
            search_kwargs.update(kwargs)

        results = self.backend.search(final_query, **search_kwargs)
        self._results = results.get('results', [])
        self._hit_count = results.get('hits', 0)
        self._facet_counts = self.post_process_facets(results)
        self._spelling_suggestion = results.get('spelling_suggestion', None)

    def run_mlt(self, **kwargs):
        """
        Executes the More Like This. Returns a list of search results similar
        to the provided document (and optionally query).
        """
        if self._more_like_this is False or self._mlt_instance is None:
            raise MoreLikeThisError("No instance was provided to determine 'More Like This' results.")

        search_kwargs = {
            'result_class': self.result_class,
        }

        if self.models:
            search_kwargs['models'] = self.models

        if kwargs:
            search_kwargs.update(kwargs)

        additional_query_string = self.build_query()
        results = self.backend.more_like_this(self._mlt_instance, additional_query_string, **search_kwargs)
        self._results = results.get('results', [])
        self._hit_count = results.get('hits', 0)

    def run_raw(self, **kwargs):
        """Executes a raw query. Returns a list of search results."""
        search_kwargs = self.build_params()
        search_kwargs.update(self._raw_query_params)

        if kwargs:
            search_kwargs.update(kwargs)

        results = self.backend.search(self._raw_query, **search_kwargs)
        self._results = results.get('results', [])
        self._hit_count = results.get('hits', 0)
        self._facet_counts = results.get('facets', {})
        self._spelling_suggestion = results.get('spelling_suggestion', None)

    def get_count(self):
        """
        Returns the number of results the backend found for the query.

        If the query has not been run, this will execute the query and store
        the results.
        """
        if self._hit_count is None:
            # Limit the slice to 1 so we get a count without consuming
            # everything.
            if not self.end_offset:
                self.end_offset = 1

            if self._more_like_this:
                # Special case for MLT.
                self.run_mlt()
            elif self._raw_query:
                # Special case for raw queries.
                self.run_raw()
            else:
                self.run()

        return self._hit_count

    def get_results(self, **kwargs):
        """
        Returns the results received from the backend.

        If the query has not been run, this will execute the query and store
        the results.
        """
        if self._results is None:
            if self._more_like_this:
                # Special case for MLT.
                self.run_mlt(**kwargs)
            elif self._raw_query:
                # Special case for raw queries.
                self.run_raw(**kwargs)
            else:
                self.run(**kwargs)

        return self._results

    def get_facet_counts(self):
        """
        Returns the facet counts received from the backend.

        If the query has not been run, this will execute the query and store
        the results.
        """
        if self._facet_counts is None:
            self.run()

        return self._facet_counts

    def get_spelling_suggestion(self, preferred_query=None):
        """
        Returns the spelling suggestion received from the backend.

        If the query has not been run, this will execute the query and store
        the results.
        """
        if self._spelling_suggestion is None:
            self.run(spelling_query=preferred_query)

        return self._spelling_suggestion

    def boost_fragment(self, boost_word, boost_value):
        """Generates query fragment for boosting a single word/value pair."""
        return "%s^%s" % (boost_word, boost_value)

    def matching_all_fragment(self):
        """Generates the query that matches all documents."""
        return '*'

    def build_query(self):
        """
        Interprets the collected query metadata and builds the final query to
        be sent to the backend.
        """
        final_query = self.query_filter.as_query_string(self.build_query_fragment)

        if not final_query:
            # Match all.
            final_query = self.matching_all_fragment()

        if self.boost:
            boost_list = []

            for boost_word, boost_value in self.boost.items():
                boost_list.append(self.boost_fragment(boost_word, boost_value))

            final_query = "%s %s" % (final_query, " ".join(boost_list))

        return final_query

    def combine(self, rhs, connector=SQ.AND):
        if connector == SQ.AND:
            self.add_filter(rhs.query_filter)
        elif connector == SQ.OR:
            self.add_filter(rhs.query_filter, use_or=True)

    # Methods for backends to implement.

    def build_query_fragment(self, field, filter_type, value):
        """
        Generates a query fragment from a field, filter type and a value.

        Must be implemented in backends as this will be highly backend specific.
        """
        raise NotImplementedError("Subclasses must provide a way to generate query fragments via the 'build_query_fragment' method.")


    # Standard methods to alter the query.

    def clean(self, query_fragment):
        """
        Provides a mechanism for sanitizing user input before presenting the
        value to the backend.

        A basic (override-able) implementation is provided.
        """
        if not isinstance(query_fragment, basestring):
            return query_fragment

        words = query_fragment.split()
        cleaned_words = []

        for word in words:
            if word in self.backend.RESERVED_WORDS:
                word = word.replace(word, word.lower())

            for char in self.backend.RESERVED_CHARACTERS:
                word = word.replace(char, '\\%s' % char)

            cleaned_words.append(word)

        return ' '.join(cleaned_words)

    def build_not_query(self, query_string):
        if ' ' in query_string:
            query_string = "(%s)" % query_string

        return u"NOT %s" % query_string

    def build_exact_query(self, query_string):
        return u'"%s"' % query_string

    def add_filter(self, query_filter, use_or=False):
        """
        Adds a SQ to the current query.
        """
        if use_or:
            connector = SQ.OR
        else:
            connector = SQ.AND

        if self.query_filter and query_filter.connector != connector and len(query_filter) > 1:
            self.query_filter.start_subtree(connector)
            subtree = True
        else:
            subtree = False

        for child in query_filter.children:
            if isinstance(child, tree.Node):
                self.query_filter.start_subtree(connector)
                self.add_filter(child)
                self.query_filter.end_subtree()
            else:
                expression, value = child
                self.query_filter.add((expression, value), connector)

            connector = query_filter.connector

        if query_filter.negated:
            self.query_filter.negate()

        if subtree:
            self.query_filter.end_subtree()

    def add_order_by(self, field):
        """Orders the search result by a field."""
        self.order_by.append(field)

    def add_order_by_distance(self, **kwargs):
        """Orders the search result by distance from point."""
        raise NotImplementedError("Subclasses must provide a way to add order by distance in the 'add_order_by_distance' method.")

    def clear_order_by(self):
        """
        Clears out all ordering that has been already added, reverting the
        query to relevancy.
        """
        self.order_by = []

    def clear_order_by_distance(self):
        """
        Clears out all distance ordering that has been already added, reverting the
        query to relevancy.
        """
        self.order_by_distance = []

    def add_model(self, model):
        """
        Restricts the query requiring matches in the given model.

        This builds upon previous additions, so you can limit to multiple models
        by chaining this method several times.
        """
        if not isinstance(model, ModelBase):
            raise AttributeError('The model being added to the query must derive from Model.')

        self.models.add(model)

    def set_limits(self, low=None, high=None):
        """Restricts the query by altering either the start, end or both offsets."""
        if low is not None:
            self.start_offset = int(low)

        if high is not None:
            self.end_offset = int(high)

    def clear_limits(self):
        """Clears any existing limits."""
        self.start_offset, self.end_offset = 0, None

    def add_boost(self, term, boost_value):
        """Adds a boosted term and the amount to boost it to the query."""
        self.boost[term] = boost_value

    def raw_search(self, query_string, **kwargs):
        """
        Runs a raw query (no parsing) against the backend.

        This method causes the SearchQuery to ignore the standard query
        generating facilities, running only what was provided instead.

        Note that any kwargs passed along will override anything provided
        to the rest of the ``SearchQuerySet``.
        """
        self._raw_query = query_string
        self._raw_query_params = kwargs

    def more_like_this(self, model_instance):
        """
        Allows backends with support for "More Like This" to return results
        similar to the provided instance.
        """
        self._more_like_this = True
        self._mlt_instance = model_instance

    def add_highlight(self):
        """Adds highlighting to the search results."""
        self.highlight = True

    def add_within(self, field, point_1, point_2):
        """Adds bounding box parameters to search query."""
        from haystack.utils.geo import ensure_point
        self.within = {
            'field': field,
            'point_1': ensure_point(point_1),
            'point_2': ensure_point(point_2),
        }

    def add_dwithin(self, field, point, distance):
        """Adds radius-based parameters to search query."""
        from haystack.utils.geo import ensure_point, ensure_distance
        self.dwithin = {
            'field': field,
            'point': ensure_point(point),
            'distance': ensure_distance(distance),
        }

    def add_distance(self, field, point):
        """
        Denotes that results should include distance measurements from the
        point passed in.
        """
        from haystack.utils.geo import ensure_point
        self.distance_point = {
            'field': field,
            'point': ensure_point(point),
        }

    def add_field_facet(self, field, **options):
        """Adds a regular facet on a field."""
        from haystack import connections
        field_name = connections[self._using].get_unified_index().get_facet_fieldname(field)
        self.facets[field_name] = options.copy()

    def add_date_facet(self, field, start_date, end_date, gap_by, gap_amount=1):
        """Adds a date-based facet on a field."""
        from haystack import connections
        if not gap_by in VALID_GAPS:
            raise FacetingError("The gap_by ('%s') must be one of the following: %s." % (gap_by, ', '.join(VALID_GAPS)))

        details = {
            'start_date': start_date,
            'end_date': end_date,
            'gap_by': gap_by,
            'gap_amount': gap_amount,
        }
        self.date_facets[connections[self._using].get_unified_index().get_facet_fieldname(field)] = details

    def add_query_facet(self, field, query):
        """Adds a query facet on a field."""
        from haystack import connections
        self.query_facets.append((connections[self._using].get_unified_index().get_facet_fieldname(field), query))

    def add_narrow_query(self, query):
        """
        Narrows a search to a subset of all documents per the query.

        Generally used in conjunction with faceting.
        """
        self.narrow_queries.add(query)

    def set_result_class(self, klass):
        """
        Sets the result class to use for results.

        Overrides any previous usages. If ``None`` is provided, Haystack will
        revert back to the default ``SearchResult`` object.
        """
        if klass is None:
            klass = SearchResult

        self.result_class = klass

    def post_process_facets(self, results):
        # Handle renaming the facet fields. Undecorate and all that.
        from haystack import connections
        revised_facets = {}
        field_data = connections[self._using].get_unified_index().all_searchfields()

        for facet_type, field_details in results.get('facets', {}).items():
            temp_facets = {}

            for field, field_facets in field_details.items():
                fieldname = field
                if field in field_data and hasattr(field_data[field], 'get_facet_for_name'):
                    fieldname = field_data[field].get_facet_for_name()

                temp_facets[fieldname] = field_facets

            revised_facets[facet_type] = temp_facets

        return revised_facets

    def using(self, using=None):
        """
        Allows for overriding which connection should be used. This
        disables the use of routers when performing the query.

        If ``None`` is provided, it has no effect on what backend is used.
        """
        return self._clone(using=using)

    def _reset(self):
        """
        Resets the instance's internal state to appear as though no query has
        been run before. Only need to tweak a few variables we check.
        """
        self._results = None
        self._hit_count = None
        self._facet_counts = None
        self._spelling_suggestion = None

    def _clone(self, klass=None, using=None):
        if using is None:
            using = self._using
        else:
            from haystack import connections
            klass = connections[using].query

        if klass is None:
            klass = self.__class__

        clone = klass(using=using)
        clone.query_filter = deepcopy(self.query_filter)
        clone.order_by = self.order_by[:]
        clone.models = self.models.copy()
        clone.boost = self.boost.copy()
        clone.highlight = self.highlight
        clone.facets = self.facets.copy()
        clone.date_facets = self.date_facets.copy()
        clone.query_facets = self.query_facets[:]
        clone.narrow_queries = self.narrow_queries.copy()
        clone.start_offset = self.start_offset
        clone.end_offset = self.end_offset
        clone.result_class = self.result_class
        clone.within = self.within.copy()
        clone.dwithin = self.dwithin.copy()
        clone.distance_point = self.distance_point.copy()
        clone._raw_query = self._raw_query
        clone._raw_query_params = self._raw_query_params
        return clone


class BaseEngine(object):
    backend = BaseSearchBackend
    query = BaseSearchQuery
    unified_index = UnifiedIndex

    def __init__(self, using=None):
        if using is None:
            using = DEFAULT_ALIAS

        self.using = using
        self.options = settings.HAYSTACK_CONNECTIONS.get(self.using, {})
        self.queries = []
        self._index = None
        self._backend = None

    def get_backend(self):
        if self._backend is None:
            self._backend = self.backend(self.using, **self.options)
        return self._backend

    def get_query(self):
        return self.query(using=self.using)

    def reset_queries(self):
        self.queries = []

    def get_unified_index(self):
        if self._index is None:
            self._index = self.unified_index(self.options.get('EXCLUDED_INDEXES', []))

        return self._index
