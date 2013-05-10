import warnings
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.db.models.loading import get_model
from haystack.backends import BaseEngine, BaseSearchBackend, BaseSearchQuery, log_query, EmptyResults
from haystack.constants import ID, DJANGO_CT, DJANGO_ID
from haystack.exceptions import MissingDependency, MoreLikeThisError
from haystack.inputs import PythonData, Clean, Exact
from haystack.models import SearchResult
from haystack.utils import get_identifier
from haystack.utils import log as logging

try:
    from pysolr import Solr, SolrError
except ImportError:
    raise MissingDependency("The 'solr' backend requires the installation of 'pysolr'. Please refer to the documentation.")


class SolrSearchBackend(BaseSearchBackend):
    # Word reserved by Solr for special use.
    RESERVED_WORDS = (
        'AND',
        'NOT',
        'OR',
        'TO',
    )

    # Characters reserved by Solr for special use.
    # The '\\' must come first, so as not to overwrite the other slash replacements.
    RESERVED_CHARACTERS = (
        '\\', '+', '-', '&&', '||', '!', '(', ')', '{', '}',
        '[', ']', '^', '"', '~', '*', '?', ':',
    )

    def __init__(self, connection_alias, **connection_options):
        super(SolrSearchBackend, self).__init__(connection_alias, **connection_options)

        if not 'URL' in connection_options:
            raise ImproperlyConfigured("You must specify a 'URL' in your settings for connection '%s'." % connection_alias)

        self.conn = Solr(connection_options['URL'], timeout=self.timeout)
        self.log = logging.getLogger('haystack')

    def update(self, index, iterable, commit=True):
        docs = []

        for obj in iterable:
            try:
                docs.append(index.full_prepare(obj))
            except UnicodeDecodeError:
                if not self.silently_fail:
                    raise

                # We'll log the object identifier but won't include the actual object
                # to avoid the possibility of that generating encoding errors while
                # processing the log message:
                self.log.error(u"UnicodeDecodeError while preparing object for update", exc_info=True, extra={
                    "data": {
                        "index": index,
                        "object": get_identifier(obj)
                    }
                })

        if len(docs) > 0:
            try:
                self.conn.add(docs, commit=commit, boost=index.get_field_weights())
            except (IOError, SolrError), e:
                if not self.silently_fail:
                    raise

                self.log.error("Failed to add documents to Solr: %s", e)

    def remove(self, obj_or_string, commit=True):
        solr_id = get_identifier(obj_or_string)

        try:
            kwargs = {
                'commit': commit,
                ID: solr_id
            }
            self.conn.delete(**kwargs)
        except (IOError, SolrError), e:
            if not self.silently_fail:
                raise

            self.log.error("Failed to remove document '%s' from Solr: %s", solr_id, e)

    def clear(self, models=[], commit=True):
        try:
            if not models:
                # *:* matches all docs in Solr
                self.conn.delete(q='*:*', commit=commit)
            else:
                models_to_delete = []

                for model in models:
                    models_to_delete.append("%s:%s.%s" % (DJANGO_CT, model._meta.app_label, model._meta.module_name))

                self.conn.delete(q=" OR ".join(models_to_delete), commit=commit)

            # Run an optimize post-clear. http://wiki.apache.org/solr/FAQ#head-9aafb5d8dff5308e8ea4fcf4b71f19f029c4bb99
            self.conn.optimize()
        except (IOError, SolrError), e:
            if not self.silently_fail:
                raise

            if len(models):
                self.log.error("Failed to clear Solr index of models '%s': %s", ','.join(models_to_delete), e)
            else:
                self.log.error("Failed to clear Solr index: %s", e)

    @log_query
    def search(self, query_string, **kwargs):
        if len(query_string) == 0:
            return {
                'results': [],
                'hits': 0,
            }

        search_kwargs = self.build_search_kwargs(query_string, **kwargs)

        try:
            raw_results = self.conn.search(query_string, **search_kwargs)
        except (IOError, SolrError), e:
            if not self.silently_fail:
                raise

            self.log.error("Failed to query Solr using '%s': %s", query_string, e)
            raw_results = EmptyResults()

        return self._process_results(raw_results, highlight=kwargs.get('highlight'), result_class=kwargs.get('result_class', SearchResult), distance_point=kwargs.get('distance_point'))

    def build_search_kwargs(self, query_string, sort_by=None, start_offset=0, end_offset=None,
                            fields='', highlight=False, facets=None,
                            date_facets=None, query_facets=None,
                            narrow_queries=None, spelling_query=None,
                            within=None, dwithin=None, distance_point=None,
                            models=None, limit_to_registered_models=None,
                            result_class=None):
        kwargs = {'fl': '* score'}

        if fields:
            if isinstance(fields, (list, set)):
                fields = " ".join(fields)

            kwargs['fl'] = fields

        if sort_by is not None:
            if sort_by in ['distance asc', 'distance desc'] and distance_point:
                # Do the geo-enabled sort.
                lng, lat = distance_point['point'].get_coords()
                kwargs['sfield'] = distance_point['field']
                kwargs['pt'] = '%s,%s' % (lat, lng)

                if sort_by == 'distance asc':
                    kwargs['sort'] = 'geodist() asc'
                else:
                    kwargs['sort'] = 'geodist() desc'
            else:
                if sort_by.startswith('distance '):
                    warnings.warn("In order to sort by distance, you must call the '.distance(...)' method.")

                # Regular sorting.
                kwargs['sort'] = sort_by

        if start_offset is not None:
            kwargs['start'] = start_offset

        if end_offset is not None:
            kwargs['rows'] = end_offset - start_offset

        if highlight is True:
            kwargs['hl'] = 'true'
            kwargs['hl.fragsize'] = '200'

        if self.include_spelling is True:
            kwargs['spellcheck'] = 'true'
            kwargs['spellcheck.collate'] = 'true'
            kwargs['spellcheck.count'] = 1

            if spelling_query:
                kwargs['spellcheck.q'] = spelling_query

        if facets is not None:
            kwargs['facet'] = 'on'
            kwargs['facet.field'] = facets.keys()

            for facet_field, options in facets.items():
                for key, value in options.items():
                    kwargs['f.%s.facet.%s' % (facet_field, key)] = self.conn._from_python(value)

        if date_facets is not None:
            kwargs['facet'] = 'on'
            kwargs['facet.date'] = date_facets.keys()
            kwargs['facet.date.other'] = 'none'

            for key, value in date_facets.items():
                kwargs["f.%s.facet.date.start" % key] = self.conn._from_python(value.get('start_date'))
                kwargs["f.%s.facet.date.end" % key] = self.conn._from_python(value.get('end_date'))
                gap_by_string = value.get('gap_by').upper()
                gap_string = "%d%s" % (value.get('gap_amount'), gap_by_string)

                if value.get('gap_amount') != 1:
                    gap_string += "S"

                kwargs["f.%s.facet.date.gap" % key] = '+%s/%s' % (gap_string, gap_by_string)

        if query_facets is not None:
            kwargs['facet'] = 'on'
            kwargs['facet.query'] = ["%s:%s" % (field, value) for field, value in query_facets]

        if limit_to_registered_models is None:
            limit_to_registered_models = getattr(settings, 'HAYSTACK_LIMIT_TO_REGISTERED_MODELS', True)

        if models and len(models):
            model_choices = sorted(['%s.%s' % (model._meta.app_label, model._meta.module_name) for model in models])
        elif limit_to_registered_models:
            # Using narrow queries, limit the results to only models handled
            # with the current routers.
            model_choices = self.build_models_list()
        else:
            model_choices = []

        if len(model_choices) > 0:
            if narrow_queries is None:
                narrow_queries = set()

            narrow_queries.add('%s:(%s)' % (DJANGO_CT, ' OR '.join(model_choices)))

        if narrow_queries is not None:
            kwargs['fq'] = list(narrow_queries)

        if within is not None:
            from haystack.utils.geo import generate_bounding_box

            kwargs.setdefault('fq', [])
            ((min_lat, min_lng), (max_lat, max_lng)) = generate_bounding_box(within['point_1'], within['point_2'])
            # Bounding boxes are min, min TO max, max. Solr's wiki was *NOT*
            # very clear on this.
            bbox = '%s:[%s,%s TO %s,%s]' % (within['field'], min_lat, min_lng, max_lat, max_lng)
            kwargs['fq'].append(bbox)

        if dwithin is not None:
            kwargs.setdefault('fq', [])
            lng, lat = dwithin['point'].get_coords()
            geofilt = '{!geofilt pt=%s,%s sfield=%s d=%s}' % (lat, lng, dwithin['field'], dwithin['distance'].km)
            kwargs['fq'].append(geofilt)

        # Check to see if the backend should try to include distances
        # (Solr 4.X+) in the results.
        if self.distance_available and distance_point:
            # In early testing, you can't just hand Solr 4.X a proper bounding box
            # & request distances. To enable native distance would take calculating
            # a center point & a radius off the user-provided box, which kinda
            # sucks. We'll avoid it for now, since Solr 4.x's release will be some
            # time yet.
            # kwargs['fl'] += ' _dist_:geodist()'
            pass

        return kwargs

    def more_like_this(self, model_instance, additional_query_string=None,
                       start_offset=0, end_offset=None, models=None,
                       limit_to_registered_models=None, result_class=None, **kwargs):
        from haystack import connections

        # Deferred models will have a different class ("RealClass_Deferred_fieldname")
        # which won't be in our registry:
        model_klass = model_instance._meta.concrete_model

        index = connections[self.connection_alias].get_unified_index().get_index(model_klass)
        field_name = index.get_content_field()
        params = {
            'fl': '*,score',
        }

        if start_offset is not None:
            params['start'] = start_offset

        if end_offset is not None:
            params['rows'] = end_offset

        narrow_queries = set()

        if limit_to_registered_models is None:
            limit_to_registered_models = getattr(settings, 'HAYSTACK_LIMIT_TO_REGISTERED_MODELS', True)

        if models and len(models):
            model_choices = sorted(['%s.%s' % (model._meta.app_label, model._meta.module_name) for model in models])
        elif limit_to_registered_models:
            # Using narrow queries, limit the results to only models handled
            # with the current routers.
            model_choices = self.build_models_list()
        else:
            model_choices = []

        if len(model_choices) > 0:
            if narrow_queries is None:
                narrow_queries = set()

            narrow_queries.add('%s:(%s)' % (DJANGO_CT, ' OR '.join(model_choices)))

        if additional_query_string:
            narrow_queries.add(additional_query_string)

        if narrow_queries:
            params['fq'] = list(narrow_queries)

        query = "%s:%s" % (ID, get_identifier(model_instance))

        try:
            raw_results = self.conn.more_like_this(query, field_name, **params)
        except (IOError, SolrError), e:
            if not self.silently_fail:
                raise

            self.log.error("Failed to fetch More Like This from Solr for document '%s': %s", query, e)
            raw_results = EmptyResults()

        return self._process_results(raw_results, result_class=result_class)

    def _process_results(self, raw_results, highlight=False, result_class=None, distance_point=None):
        from haystack import connections
        results = []
        hits = raw_results.hits
        facets = {}
        spelling_suggestion = None

        if result_class is None:
            result_class = SearchResult

        if hasattr(raw_results, 'facets'):
            facets = {
                'fields': raw_results.facets.get('facet_fields', {}),
                'dates': raw_results.facets.get('facet_dates', {}),
                'queries': raw_results.facets.get('facet_queries', {}),
            }

            for key in ['fields']:
                for facet_field in facets[key]:
                    # Convert to a two-tuple, as Solr's json format returns a list of
                    # pairs.
                    facets[key][facet_field] = zip(facets[key][facet_field][::2], facets[key][facet_field][1::2])

        if self.include_spelling is True:
            if hasattr(raw_results, 'spellcheck'):
                if len(raw_results.spellcheck.get('suggestions', [])):
                    # For some reason, it's an array of pairs. Pull off the
                    # collated result from the end.
                    spelling_suggestion = raw_results.spellcheck.get('suggestions')[-1]

        unified_index = connections[self.connection_alias].get_unified_index()
        indexed_models = unified_index.get_indexed_models()

        for raw_result in raw_results.docs:
            app_label, model_name = raw_result[DJANGO_CT].split('.')
            additional_fields = {}
            model = get_model(app_label, model_name)

            if model and model in indexed_models:
                for key, value in raw_result.items():
                    index = unified_index.get_index(model)
                    string_key = str(key)

                    if string_key in index.fields and hasattr(index.fields[string_key], 'convert'):
                        additional_fields[string_key] = index.fields[string_key].convert(value)
                    else:
                        additional_fields[string_key] = self.conn._to_python(value)

                del(additional_fields[DJANGO_CT])
                del(additional_fields[DJANGO_ID])
                del(additional_fields['score'])

                if raw_result[ID] in getattr(raw_results, 'highlighting', {}):
                    additional_fields['highlighted'] = raw_results.highlighting[raw_result[ID]]

                if distance_point:
                    additional_fields['_point_of_origin'] = distance_point

                    if raw_result.get('__dist__'):
                        from haystack.utils.geo import Distance
                        additional_fields['_distance'] = Distance(km=float(raw_result['__dist__']))
                    else:
                        additional_fields['_distance'] = None

                result = result_class(app_label, model_name, raw_result[DJANGO_ID], raw_result['score'], **additional_fields)
                results.append(result)
            else:
                hits -= 1

        return {
            'results': results,
            'hits': hits,
            'facets': facets,
            'spelling_suggestion': spelling_suggestion,
        }

    def build_schema(self, fields):
        content_field_name = ''
        schema_fields = []

        for field_name, field_class in fields.items():
            field_data = {
                'field_name': field_class.index_fieldname,
                'type': 'text_en',
                'indexed': 'true',
                'stored': 'true',
                'multi_valued': 'false',
            }

            if field_class.document is True:
                content_field_name = field_class.index_fieldname

            # DRL_FIXME: Perhaps move to something where, if none of these
            #            checks succeed, call a custom method on the form that
            #            returns, per-backend, the right type of storage?
            if field_class.field_type in ['date', 'datetime']:
                field_data['type'] = 'date'
            elif field_class.field_type == 'integer':
                field_data['type'] = 'long'
            elif field_class.field_type == 'float':
                field_data['type'] = 'float'
            elif field_class.field_type == 'boolean':
                field_data['type'] = 'boolean'
            elif field_class.field_type == 'ngram':
                field_data['type'] = 'ngram'
            elif field_class.field_type == 'edge_ngram':
                field_data['type'] = 'edge_ngram'
            elif field_class.field_type == 'location':
                field_data['type'] = 'location'

            if field_class.is_multivalued:
                field_data['multi_valued'] = 'true'

            if field_class.stored is False:
                field_data['stored'] = 'false'

            # Do this last to override `text` fields.
            if field_class.indexed is False:
                field_data['indexed'] = 'false'

                # If it's text and not being indexed, we probably don't want
                # to do the normal lowercase/tokenize/stemming/etc. dance.
                if field_data['type'] == 'text_en':
                    field_data['type'] = 'string'

            # If it's a ``FacetField``, make sure we don't postprocess it.
            if hasattr(field_class, 'facet_for'):
                # If it's text, it ought to be a string.
                if field_data['type'] == 'text_en':
                    field_data['type'] = 'string'

            schema_fields.append(field_data)

        return (content_field_name, schema_fields)

    def extract_file_contents(self, file_obj):
        """Extract text and metadata from a structured file (PDF, MS Word, etc.)

        Uses the Solr ExtractingRequestHandler, which is based on Apache Tika.
        See the Solr wiki for details:

            http://wiki.apache.org/solr/ExtractingRequestHandler

        Due to the way the ExtractingRequestHandler is implemented it completely
        replaces the normal Haystack indexing process with several unfortunate
        restrictions: only one file per request, the extracted data is added to
        the index with no ability to modify it, etc. To simplify the process and
        allow for more advanced use we'll run using the extract-only mode to
        return the extracted data without adding it to the index so we can then
        use it within Haystack's normal templating process.

        Returns None if metadata cannot be extracted; otherwise returns a
        dictionary containing at least two keys:

            :contents:
                        Extracted full-text content, if applicable
            :metadata:
                        key:value pairs of text strings
        """

        try:
            return self.conn.extract(file_obj)
        except StandardError, e:
            self.log.warning(u"Unable to extract file contents: %s", e,
                             exc_info=True, extra={"data": {"file": file_obj}})
            return None


class SolrSearchQuery(BaseSearchQuery):
    def matching_all_fragment(self):
        return '*:*'

    def add_spatial(self, lat, lon, sfield, distance, filter='bbox'):
        """Adds spatial query parameters to search query"""
        kwargs = {
            'lat': lat,
            'long': long,
            'sfield': sfield,
            'distance': distance,
        }
        self.spatial_query.update(kwargs)

    def add_order_by_distance(self, lat, long, sfield):
        """Orders the search result by distance from point."""
        kwargs = {
            'lat': lat,
            'long': long,
            'sfield': sfield,
        }
        self.order_by_distance.update(kwargs)

    def build_query_fragment(self, field, filter_type, value):
        from haystack import connections
        query_frag = ''

        if not hasattr(value, 'input_type_name'):
            # Handle when we've got a ``ValuesListQuerySet``...
            if hasattr(value, 'values_list'):
                value = list(value)

            if isinstance(value, basestring):
                # It's not an ``InputType``. Assume ``Clean``.
                value = Clean(value)
            else:
                value = PythonData(value)

        # Prepare the query using the InputType.
        prepared_value = value.prepare(self)

        if not isinstance(prepared_value, (set, list, tuple)):
            # Then convert whatever we get back to what pysolr wants if needed.
            prepared_value = self.backend.conn._from_python(prepared_value)

        # 'content' is a special reserved word, much like 'pk' in
        # Django's ORM layer. It indicates 'no special field'.
        if field == 'content':
            index_fieldname = ''
        else:
            index_fieldname = u'%s:' % connections[self._using].get_unified_index().get_index_fieldname(field)

        filter_types = {
            'contains': u'%s',
            'startswith': u'%s*',
            'exact': u'%s',
            'gt': u'{%s TO *}',
            'gte': u'[%s TO *]',
            'lt': u'{* TO %s}',
            'lte': u'[* TO %s]',
        }

        if value.post_process is False:
            query_frag = prepared_value
        else:
            if filter_type in ['contains', 'startswith']:
                if value.input_type_name == 'exact':
                    query_frag = prepared_value
                else:
                    # Iterate over terms & incorportate the converted form of each into the query.
                    terms = []

                    for possible_value in prepared_value.split(' '):
                        terms.append(filter_types[filter_type] % self.backend.conn._from_python(possible_value))

                    if len(terms) == 1:
                        query_frag = terms[0]
                    else:
                        query_frag = u"(%s)" % " AND ".join(terms)
            elif filter_type == 'in':
                in_options = []

                for possible_value in prepared_value:
                    in_options.append(u'"%s"' % self.backend.conn._from_python(possible_value))

                query_frag = u"(%s)" % " OR ".join(in_options)
            elif filter_type == 'range':
                start = self.backend.conn._from_python(prepared_value[0])
                end = self.backend.conn._from_python(prepared_value[1])
                query_frag = u'["%s" TO "%s"]' % (start, end)
            elif filter_type == 'exact':
                if value.input_type_name == 'exact':
                    query_frag = prepared_value
                else:
                    prepared_value = Exact(prepared_value).prepare(self)
                    query_frag = filter_types[filter_type] % prepared_value
            else:
                if value.input_type_name != 'exact':
                    prepared_value = Exact(prepared_value).prepare(self)

                query_frag = filter_types[filter_type] % prepared_value

        if len(query_frag) and not query_frag.startswith('(') and not query_frag.endswith(')'):
            query_frag = "(%s)" % query_frag

        return u"%s%s" % (index_fieldname, query_frag)

    def build_alt_parser_query(self, parser_name, query_string='', **kwargs):
        if query_string:
            query_string = Clean(query_string).prepare(self)

        kwarg_bits = []

        for key in sorted(kwargs.keys()):
            if isinstance(kwargs[key], basestring) and ' ' in kwargs[key]:
                kwarg_bits.append(u"%s='%s'" % (key, kwargs[key]))
            else:
                kwarg_bits.append(u"%s=%s" % (key, kwargs[key]))

        return u'_query_:"{!%s %s}%s"' % (parser_name, Clean(' '.join(kwarg_bits)), query_string)

    def build_params(self, spelling_query=None, **kwargs):
        search_kwargs = {
            'start_offset': self.start_offset,
            'result_class': self.result_class
        }        
        order_by_list = None

        if self.order_by:
            if order_by_list is None:
                order_by_list = []

            for order_by in self.order_by:
                if order_by.startswith('-'):
                    order_by_list.append('%s desc' % order_by[1:])
                else:
                    order_by_list.append('%s asc' % order_by)

            search_kwargs['sort_by'] = ", ".join(order_by_list)

        if self.date_facets:
            search_kwargs['date_facets'] = self.date_facets

        if self.distance_point:
            search_kwargs['distance_point'] = self.distance_point

        if self.dwithin:
            search_kwargs['dwithin'] = self.dwithin

        if self.end_offset is not None:
            search_kwargs['end_offset'] = self.end_offset

        if self.facets:
            search_kwargs['facets'] = self.facets

        if self.fields:
            search_kwargs['fields'] = self.fields

        if self.highlight:
            search_kwargs['highlight'] = self.highlight

        if self.models:
            search_kwargs['models'] = self.models

        if self.narrow_queries:
            search_kwargs['narrow_queries'] = self.narrow_queries

        if self.query_facets:
            search_kwargs['query_facets'] = self.query_facets

        if self.within:
            search_kwargs['within'] = self.within

        if spelling_query:
            search_kwargs['spelling_query'] = spelling_query

        return search_kwargs
        
    def run(self, spelling_query=None, **kwargs):
        """Builds and executes the query. Returns a list of search results."""
        final_query = self.build_query()
        search_kwargs = self.build_params(spelling_query, **kwargs)
        results = self.backend.search(final_query, **search_kwargs)
        self._results = results.get('results', [])
        self._hit_count = results.get('hits', 0)
        self._facet_counts = self.post_process_facets(results)
        self._spelling_suggestion = results.get('spelling_suggestion', None)

    def run_mlt(self, **kwargs):
        """Builds and executes the query. Returns a list of search results."""
        if self._more_like_this is False or self._mlt_instance is None:
            raise MoreLikeThisError("No instance was provided to determine 'More Like This' results.")

        additional_query_string = self.build_query()
        search_kwargs = {
            'start_offset': self.start_offset,
            'result_class': self.result_class,
            'models': self.models
        }

        if self.end_offset is not None:
            search_kwargs['end_offset'] = self.end_offset - self.start_offset

        results = self.backend.more_like_this(self._mlt_instance, additional_query_string, **search_kwargs)
        self._results = results.get('results', [])
        self._hit_count = results.get('hits', 0)


class SolrEngine(BaseEngine):
    backend = SolrSearchBackend
    query = SolrSearchQuery
