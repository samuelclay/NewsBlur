"""
A very basic, ORM-based backend for simple search during tests.
"""
from django.conf import settings
from django.db.models import Q
from haystack import connections
from haystack.backends import BaseEngine, BaseSearchBackend, BaseSearchQuery, SearchNode, log_query
from haystack.inputs import PythonData
from haystack.models import SearchResult


if settings.DEBUG:
    import logging

    class NullHandler(logging.Handler):
        def emit(self, record):
            pass

    ch = logging.StreamHandler()
    ch.setLevel(logging.WARNING)
    ch.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))

    logger = logging.getLogger('haystack.simple_backend')
    logger.setLevel(logging.WARNING)
    logger.addHandler(NullHandler())
    logger.addHandler(ch)
else:
    logger = None

class SimpleSearchBackend(BaseSearchBackend):
    def update(self, indexer, iterable, commit=True):
        if logger is not None:
            logger.warning('update is not implemented in this backend')

    def remove(self, obj, commit=True):
        if logger is not None:
            logger.warning('remove is not implemented in this backend')

    def clear(self, models=[], commit=True):
        if logger is not None:
            logger.warning('clear is not implemented in this backend')

    @log_query
    def search(self, query_string, **kwargs):
        hits = 0
        results = []
        result_class = SearchResult
        models = connections[self.connection_alias].get_unified_index().get_indexed_models()

        if kwargs.get('result_class'):
            result_class = kwargs['result_class']

        if kwargs.get('models'):
            models = kwargs['models']

        if query_string:
            for model in models:
                if query_string == '*':
                    qs = model.objects.all()
                else:
                    for term in query_string.split():
                        queries = []

                        for field in model._meta._fields():
                            if hasattr(field, 'related'):
                                continue

                            if not field.get_internal_type() in ('TextField', 'CharField', 'SlugField'):
                                continue

                            queries.append(Q(**{'%s__icontains' % field.name: term}))

                        qs = model.objects.filter(reduce(lambda x, y: x|y, queries))

                hits += len(qs)

                for match in qs:
                    match.__dict__.pop('score', None)
                    result = result_class(match._meta.app_label, match._meta.module_name, match.pk, 0, **match.__dict__)
                    # For efficiency.
                    result._model = match.__class__
                    result._object = match
                    results.append(result)

        return {
            'results': results,
            'hits': hits,
        }

    def prep_value(self, db_field, value):
        return value

    def more_like_this(self, model_instance, additional_query_string=None,
                       start_offset=0, end_offset=None,
                       limit_to_registered_models=None, result_class=None, **kwargs):
        return {
            'results': [],
            'hits': 0
        }


class SimpleSearchQuery(BaseSearchQuery):
    def build_query(self):
        if not self.query_filter:
            return '*'

        return self._build_sub_query(self.query_filter)

    def _build_sub_query(self, search_node):
        term_list = []

        for child in search_node.children:
            if isinstance(child, SearchNode):
                term_list.append(self._build_sub_query(child))
            else:
                value = child[1]

                if not hasattr(value, 'input_type_name'):
                    value = PythonData(value)

                term_list.append(value.prepare(self))

        return (' ').join(map(str, term_list))


class SimpleEngine(BaseEngine):
    backend = SimpleSearchBackend
    query = SimpleSearchQuery
