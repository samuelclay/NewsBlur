from django.db.models.query import QuerySet
from django.db import backend, connection
from django.core.cache import cache
from django.conf import settings

from utils import get_cache_key_for_pk
from exceptions import CacheMissingWarning

# TODO: if the query is passing pks then we need to make it pull the cache key from the model
# and try to fetch that first
# if there are additional filters to apply beyond pks we then filter those after we're already pulling the pks

# TODO: should we also run these additional filters each time we pull back a ref list to check for validation?

# TODO: all related field calls need to be removed and replaced with cache key sets of some sorts
# (just remove the join and make it do another qs.filter(pk__in) to pull them, which would do a many cache get callb)

DEFAULT_CACHE_TIME = 60*60*24 # 24 hours
GET_ITERATOR_CHUNK_SIZE = 100

class FauxCachedQuerySet(list):
    """
    We generate a FauxCachedQuerySet when we are returning a
    CachedQuerySet from a CachedModel.
    """
    pass

class CachedQuerySet(QuerySet):
    """
    Extends the QuerySet object and caches results via CACHE_BACKEND.
    """
    def __init__(self, model=None, key_prefix=None, timeout=None, key_name=None, *args, **kwargs):
        self._cache_keys = {}
        self._cache_reset = False
        self._cache_clean = False
        if key_prefix:
            self.cache_key_prefix = key_prefix
        else:
            if model:
                self.cache_key_prefix = model._meta.db_table
            else:
                self.cache_key_prefix = ''
        self.cache_key_name = key_name
        if timeout:
            self.cache_timeout = timeout
        else:
            self.cache_timeout = getattr(cache, 'default_timeout', getattr(settings, 'DEFAULT_CACHE_TIME', DEFAULT_CACHE_TIME))
        QuerySet.__init__(self, model, *args, **kwargs)

    def _clone(self, klass=None, **kwargs):
        c = QuerySet._clone(self, klass, **kwargs)
        c._cache_clean = kwargs.pop('_cache_clean', self._cache_clean)
        c._cache_reset = kwargs.pop('_cache_reset', self._cache_reset)
        c.cache_key_prefix = kwargs.pop('cache_key_prefix', self.cache_key_prefix)
        c.cache_timeout = kwargs.pop('cache_timeout', self.cache_timeout)
        c._cache_keys = {}
        return c

    def _get_sorted_clause_key(self):
        return (isinstance(i, basestring) and i.lower().replace('`', '').replace("'", '') or str(tuple(sorted(i))) for i in self._get_sql_clause())

    def _get_cache_key(self, extra=''):
        # TODO: Need to figure out if this is the best use.
        # Maybe we should use extra for cache_key_name, extra was planned for use
        # in things like .count() as it's a different cache key than the normal queryset,
        # but that also doesn't make sense because theoretically count() is already different
        # sql so the sorted_sql_clause should have figured that out.
        if self.cache_key_name is not None:
            return '%s:%s' % (self.cache_key_prefix, self.cache_key_name)
        if extra not in self._cache_keys:
            self._cache_keys[extra] = '%s:%s:%s' % (self.cache_key_prefix, str(hash(''.join(self._get_sorted_clause_key()))), extra)
        return self._cache_keys[extra]

    def _prepare_queryset_for_cache(self, queryset):
        """
        This is where the magic happens. We need to first see if our result set
        is in the cache. If it isn't, we need to do the query and set the cache
        to (ModelClass, (*<pks>,), (*<select_related fields>,), <n keys>).
        """
        # TODO: make this split up large sets of data based on an option
        # and sets the last param, keys, to how many datasets are stored
        # in the cache to regenerate.
        keys = tuple(obj.pk for obj in queryset)
        if self._select_related:
            if not self._max_related_depth:
                fields = [f.name for f in opts.fields if f.rel and not f.null]
            else:
                # TODO: handle depth relate lookups
                fields = ()
        else:
            fields = ()
    
        return (queryset[0].__class__, keys, fields, 1)

    def _get_queryset_from_cache(self, cache_object):
        """
        We transform the cache storage into an actual QuerySet object
        automagickly handling the keys depth and select_related fields (again,
        using the recursive methods of CachedQuerySet.
        
        We effectively would just be doing a cache.multi_get(*pks), grabbing
        the pks for each releation, e.g. user, and then doing a
        CachedManager.objects.filter() on them. This also then makes that
        queryset reusable. So the question is, should that queryset have been
        reusable? It could be invalidated by some other code which we aren't
        tieing directly into the parent queryset so maybe we can't do the
        objects.filter() query here and we have to do it internally.
        """
        # TODO: make this work for people who have, and who don't have, instance caching
        model, keys, fields, length = cache_object
        
        results = self._get_objects_for_keys(model, keys)
        
        if fields:
            # TODO: optimize this so it's only one get_many call instead of one per select_related field
            # XXX: this probably isn't handling depth beyond 1, didn't test even depth of 1 yet
            for f in fields:
                field = model._meta.get_field(f)
                field_results = dict((r.id, r) for r in  self._get_objects_for_keys(f.rel.to, [getattr(r, field.db_column) for r in results]))
                for r in results:
                    setattr(r, f.name, field_results[getattr(r, field.db_column)])
        return results

    def _get_objects_for_keys(self, model, keys):
        # First we fetch any keys that we can from the cache
        results = cache.get_many([get_cache_key_for_pk(model, k) for k in keys]).values()
        
        # Now we need to compute which keys weren't present in the cache
        missing = [k for k in results.iterkeys() if not results[k]]

        # We no longer need to know what the keys were so turn it into a list
        results = list(results)
        # Query for any missing objects
        # TODO: should this only be doing the cache.set if it's from a CachedModel?
        # if not then we need to expire it, hook signals?
        objects = list(model._default_manager.filter(pk__in=missing))
        for o in objects:
            cache.set(o.cache_key, o)
        results.extend(objects)

        # Do a simple len() lookup (maybe we shouldn't rely on it returning the right
        # number of objects
        cnt = len(missing) - len(objects)
        if cnt:
            raise CacheMissingWarning("%d objects missing in the database" % (cnt,))
        return results        

    def _get_data(self):
        ck = self._get_cache_key()
        if self._result_cache is None or self._cache_clean or self._cache_reset:
            if self._cache_clean:
                cache.delete(ck)
                return
            if self._cache_reset:
                result_cache = None
            else:
                result_cache = cache.get(ck)
            if result_cache is None:
                # We need to lookup the initial table queryset, without related
                # fields selected. We then need to loop through each field which
                # should be selected and doing another CachedQuerySet() call for
                # each set of data.
                
                # This will allow it to transparently, and recursively, handle
                # all calls to the cache.
                
                # We will use _prepare_queryset_for_cache to store it in the
                # the cache, and _get_queryset_from_cache to pull it.
                
                # Maybe we should override getstate and setstate instead?

                # We first have to remove select_related values from the QuerySet
                # as we don't want to pull these in to the dataset as they may already exist
                # in memory.

                # TODO: create a function that works w/ our patch and Django trunk which will
                # grab the select_related fields for us given X model and (Y list or N depth).

                # TODO: find a clean way to say "is this only matching pks?" if it is we wont
                # need to store a result set in memory but we'll need to apply the filters by hand.
                qs = QuerySet._clone(QuerySet(), **self.__dict__)
                self._result_cache = qs._get_data()
                self._cache_reset = False
                cache.set(ck, self._prepare_queryset_for_cache(self._result_cache), self.cache_timeout*60)
            else:
                try:
                    self._result_cache = self._get_queryset_from_cache(result_cache)
                except CacheMissingWarning:
                    # When an object is missing we reset the cached list.
                    # TODO: this should be some kind of option at a global and model level.
                    return self.reset()._get_data()
        return FauxCachedQuerySet(self._result_cache)

    def execute(self):
        """
        Forces execution on the queryset
        """
        self._get_data()
        return self

    def get(self, *args, **kwargs):
        """
        Performs the SELECT and returns a single object matching the given
        keyword arguments.
        """
        if self._cache_clean:
            clone = self.filter(*args, **kwargs)
            if not clone._order_by:
                clone._order_by = ()
            cache.delete(self._get_cache_key())
        else:
            return QuerySet.get(self, *args, **kwargs)

    def clean(self):
        """
        Removes queryset from the cache upon execution.
        """
        return self._clone(_cache_clean=True)

    def count(self):
        return QuerySet.count(self)
        count = cache.get(self._get_cache_key('count'))
        if count is None:
            count = int(QuerySet.count(self))
            cache.set(self._get_cache_key('count'), count, self.cache_timeout)
        return count

    def cache(self, *args, **kwargs):
        """
        Overrides CacheManager's options for this QuerySet.

        <string key_prefix> -- the key prefix for all cached objects
        on this model. [default: db_table]
        <int timeout> -- in seconds, the maximum time before data is
        invalidated.
        <string key_name> -- the key suffix for this cached queryset
        useful if you want to cache the same queryset with two expiration
        methods.
        """
        return self._clone(cache_key_prefix=kwargs.pop('key_prefix', self.cache_key_prefix), cache_timeout=kwargs.pop('timeout', self.cache_timeout), cache_key_name=kwargs.pop('key_name', self.cache_key_name))

    def reset(self):
        """
        Updates the queryset in the cache upon execution.
        """
        return self._clone(_cache_reset=True)

    def values(self, *fields):
        return self._clone(klass=CachedValuesQuerySet, _fields=fields)

# need a better way to do this.. (will mix-ins work?)
class CachedValuesQuerySet(CachedQuerySet):
    def __init__(self, *args, **kwargs):
        super(CachedQuerySet, self).__init__(*args, **kwargs)
        # select_related isn't supported in values().
        self._select_related = False

    def iterator(self):
        try:
            select, sql, params = self._get_sql_clause()
        except EmptyResultSet:
            raise StopIteration

        # self._fields is a list of field names to fetch.
        if self._fields:
            #columns = [self.model._meta.get_field(f, many_to_many=False).column for f in self._fields]
            if not self._select:
                columns = [self.model._meta.get_field(f, many_to_many=False).column for f in self._fields]
            else:
                columns = []
                for f in self._fields:
                    if f in [field.name for field in self.model._meta.fields]:
                        columns.append( self.model._meta.get_field(f, many_to_many=False).column )
                    elif not self._select.has_key( f ):
                        raise FieldDoesNotExist, '%s has no field named %r' % ( self.model._meta.object_name, f )

            field_names = self._fields
        else: # Default to all fields.
            columns = [f.column for f in self.model._meta.fields]
            field_names = [f.column for f in self.model._meta.fields]

        select = ['%s.%s' % (backend.quote_name(self.model._meta.db_table), backend.quote_name(c)) for c in columns]

        # Add any additional SELECTs.
        if self._select:
            select.extend(['(%s) AS %s' % (quote_only_if_word(s[1]), backend.quote_name(s[0])) for s in self._select.items()])

        if getattr(self, '_db_use_master', False):
            cursor = connection.write_cursor()
        else:
            cursor = connection.read_cursor()
        cursor.execute("SELECT " + (self._distinct and "DISTINCT " or "") + ",".join(select) + sql, params)
        while 1:
            rows = cursor.fetchmany(GET_ITERATOR_CHUNK_SIZE)
            if not rows:
                raise StopIteration
            for row in rows:
                yield dict(zip(field_names, row))

    def _clone(self, klass=None, **kwargs):
        c = super(CachedValuesQuerySet, self)._clone(klass, **kwargs)
        c._fields = self._fields[:]
        return c
