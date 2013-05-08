import re
import warnings
from django.utils.encoding import force_unicode


class BaseInput(object):
    """
    The base input type. Doesn't do much. You want ``Raw`` instead.
    """
    input_type_name = 'base'
    post_process = True

    def __init__(self, query_string, **kwargs):
        self.query_string = query_string
        self.kwargs = kwargs

    def __repr__(self):
        return u"<%s '%s'>" % (self.__class__.__name__, self.__unicode__().encode('utf8'))

    def __unicode__(self):
        return force_unicode(self.query_string)

    def prepare(self, query_obj):
        return self.query_string


class Raw(BaseInput):
    """
    An input type for passing a query directly to the backend.

    Prone to not being very portable.
    """
    input_type_name = 'raw'
    post_process = False


class PythonData(BaseInput):
    """
    Represents a bare Python non-string type.

    Largely only for internal use.
    """
    input_type_name = 'python_data'


class Clean(BaseInput):
    """
    An input type for sanitizing user/untrusted input.
    """
    input_type_name = 'clean'

    def prepare(self, query_obj):
        query_string = super(Clean, self).prepare(query_obj)
        return query_obj.clean(query_string)


class Exact(BaseInput):
    """
    An input type for making exact matches.
    """
    input_type_name = 'exact'

    def prepare(self, query_obj):
        query_string = super(Exact, self).prepare(query_obj)

        if self.kwargs.get('clean', False):
            # We need to clean each part of the exact match.
            exact_bits = [Clean(bit).prepare(query_obj) for bit in query_string.split(' ') if bit]
            query_string = u' '.join(exact_bits)

        return query_obj.build_exact_query(query_string)


class Not(Clean):
    """
    An input type for negating a query.
    """
    input_type_name = 'not'

    def prepare(self, query_obj):
        query_string = super(Not, self).prepare(query_obj)
        return query_obj.build_not_query(query_string)


class AutoQuery(BaseInput):
    """
    A convenience class that handles common user queries.

    In addition to cleaning all tokens, it handles double quote bits as
    exact matches & terms with '-' in front as NOT queries.
    """
    input_type_name = 'auto_query'
    post_process = False
    exact_match_re = re.compile(r'"(?P<phrase>.*?)"')

    def prepare(self, query_obj):
        query_string = super(AutoQuery, self).prepare(query_obj)
        exacts = self.exact_match_re.findall(query_string)
        tokens = []
        query_bits = []

        for rough_token in self.exact_match_re.split(query_string):
            if not rough_token:
                continue
            elif not rough_token in exacts:
                # We have something that's not an exact match but may have more
                # than on word in it.
                tokens.extend(rough_token.split(' '))
            else:
                tokens.append(rough_token)

        for token in tokens:
            if not token:
                continue
            if token in exacts:
                query_bits.append(Exact(token, clean=True).prepare(query_obj))
            elif token.startswith('-') and len(token) > 1:
                # This might break Xapian. Check on this.
                query_bits.append(Not(token[1:]).prepare(query_obj))
            else:
                query_bits.append(Clean(token).prepare(query_obj))

        return u' '.join(query_bits)


class AltParser(BaseInput):
    """
    If the engine supports it, this input type allows for submitting a query
    that uses a different parser.
    """
    input_type_name = 'alt_parser'
    post_process = False
    use_parens = False

    def __init__(self, parser_name, query_string='', **kwargs):
        self.parser_name = parser_name
        self.query_string = query_string
        self.kwargs = kwargs

    def __repr__(self):
        return u"<%s '%s' '%s' '%s'>" % (self.__class__.__name__, self.parser_name, self.query_string, self.kwargs)

    def prepare(self, query_obj):
        if not hasattr(query_obj, 'build_alt_parser_query'):
            warnings.warn("Use of 'AltParser' input type is being ignored, as the '%s' backend doesn't support them." % query_obj)
            return ''

        return query_obj.build_alt_parser_query(self.parser_name, self.query_string, **self.kwargs)
