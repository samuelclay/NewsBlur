from sys import version_info
if version_info[0:2] > (2, 2):
    from unicodedata import normalize
else:
    normalize = None

from rdflib.Identifier import Identifier
from rdflib.Literal import Literal


class URIRef(Identifier):

    def __new__(cls, value):
        return Identifier.__new__(cls, value)        

    def __init__(self, value):
        if normalize and value:
            if not isinstance(value, unicode):
                value = unicode(value)
            if value != normalize("NFC", value):
                raise Error("value must be in NFC normalized form.")

    def n3(self):
        return "<%s>" % self

