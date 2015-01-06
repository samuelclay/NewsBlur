from sys import version_info
if version_info[0:2] > (2, 2):
    from unicodedata import normalize
else:
    normalize = None

from rdflib.Identifier import Identifier
from rdflib.exceptions import Error


class Literal(Identifier):
    """

    http://www.w3.org/TR/rdf-concepts/#section-Graph-Literal
    """
    
    def __new__(cls, value, lang='', datatype=''):
        value = unicode(value)        
        return Identifier.__new__(cls, value)        

    def __init__(self, value, lang='', datatype=''):
        if normalize and value:
            if not isinstance(value, unicode):
                value = unicode(value)
            if value != normalize("NFC", value):
                raise Error("value must be in NFC normalized form.")
        
        if datatype:
            lang = ''
        self.language = lang
        self.datatype = datatype
        
    def __add__(self, val):
        s = super(Literal, self).__add__(val)
        return Literal(s, self.language, self.datatype)
    
    def n3(self):
        language = self.language
        datatype = self.datatype
        encoded = self.encode('unicode-escape')
        if language:
            if datatype:
                return '"%s"@%s^^<%s>' % (encoded, language, datatype)
            else:
                return '"%s"@%s' % (encoded, language)
        else:
            if datatype:
                return '"%s"^^<%s>' % (encoded, datatype)
            else:
                return '"%s"' % encoded


    def __eq__(self, other):
        if other==None:
            return 0
        elif isinstance(other, Literal):
            result = self.__cmp__(other)==0
            if result==1:
                if self.language==other.language:
                    return 1
                else:
                    return 0
            else:
                return result
        elif isinstance(other, Identifier):
            return 0
        else:
            return unicode(self)==other

