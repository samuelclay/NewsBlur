from string import ascii_letters
from random import choice

from rdflib.Identifier import Identifier
from rdflib.Literal import Literal

# Create a (hopefully) unique prefix so that BNode values do not
# collide with ones created with a different instance of this module.
prefix = ""
for i in xrange(0,8):
    prefix += choice(ascii_letters)

node_id = 0
class BNode(Identifier):
    def __new__(cls, value=None):
        if value==None:
            global node_id
            node_id += 1
            value = "_:%s%s" % (prefix, node_id)
        return Identifier.__new__(cls, value)
        
    def n3(self):
        return str(self)


