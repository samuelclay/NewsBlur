from haystack.query import SearchQuerySet, EmptySearchQuerySet

class HaystackManager(object):
    def __init__(self, using=None):
        super(HaystackManager, self).__init__()
        self.using = using
    
    def get_query_set(self):
        """Returns a new SearchQuerySet object.  Subclasses can override this method
        to easily customize the behavior of the Manager.
        """
        return SearchQuerySet(using=self.using)
    
    def get_empty_query_set(self):
        return EmptySearchQuerySet(using=self.using)
    
    def all(self):
        return self.get_query_set()
    
    def none(self):
        return self.get_empty_query_set()
    
    def filter(self, *args, **kwargs):
        return self.get_query_set().filter(*args, **kwargs)
    
    def exclude(self, *args, **kwargs):
        return self.get_query_set().exclude(*args, **kwargs)
    
    def filter_and(self, *args, **kwargs):
        return self.get_query_set().filter_and(*args, **kwargs)
    
    def filter_or(self, *args, **kwargs):
        return self.get_query_set().filter_or(*args, **kwargs)
    
    def order_by(self, *args):
        return self.get_query_set().order_by(*args)
    
    def order_by_distance(self, **kwargs):
        return self.get_query_set().order_by_distance(**kwargs)
    
    def highlight(self):
        return self.get_query_set().highlight()
    
    def boost(self, term, boost):
        return self.get_query_set().boost(term, boost)
    
    def facet(self, field):
        return self.get_query_set().facet(field)
    
    def within(self, field, point_1, point_2):
        return self.get_query_set().within(field, point_1, point_2)
    
    def dwithin(self, field, point, distance):
        return self.get_query_set().dwithin(field, point, distance)
    
    def distance(self, field, point):
        return self.get_query_set().distance(field, point)
    
    def date_facet(self, field, start_date, end_date, gap_by, gap_amount=1):
        return self.get_query_set().date_facet(field, start_date, end_date, gap_by, gap_amount=1)
    
    def query_facet(self, field, query):
        return self.get_query_set().query_facet(field, query)
    
    def narrow(self, query):
        return self.get_query_set().narrow(query)
    
    def raw_search(self, query_string, **kwargs):
        return self.get_query_set().raw_search(query_string,  **kwargs)
    
    def load_all(self):
        return self.get_query_set().load_all()
    
    def auto_query(self, query_string, fieldname='content'):
        return self.get_query_set().auto_query(query_string, fieldname=fieldname)
    
    def autocomplete(self, **kwargs):
        return self.get_query_set().autocomplete(**kwargs)
    
    def using(self, connection_name):
        return self.get_query_set().using(connection_name)
    
    def count(self):
        return self.get_query_set().count()
    
    def best_match(self):
        return self.get_query_set().best_match()
    
    def latest(self, date_field):
        return self.get_query_set().latest(date_field)
    
    def more_like_this(self, model_instance):
        return self.get_query_set().more_like_this(model_instance)
    
    def facet_counts(self):
        return self.get_query_set().facet_counts()
    
    def spelling_suggestion(self, preferred_query=None):
        return self.get_query_set().spelling_suggestion(preferred_query=None)
    
    def values(self, *fields):
        return self.get_query_set().values(*fields)
    
    def values_list(self, *fields, **kwargs):
        return self.get_query_set().values_list(*fields, **kwargs)

