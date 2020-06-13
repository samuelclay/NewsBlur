
__all__ = ['BaseLoader', 'SafeLoader', 'Loader']

from vendor.yaml.reader import *
from vendor.yaml.scanner import *
from vendor.yaml.parser import *
from vendor.yaml.composer import *
from vendor.yaml.constructor import *
from vendor.yaml.resolver import *

class BaseLoader(Reader, Scanner, Parser, Composer, BaseConstructor, BaseResolver):

    def __init__(self, stream):
        Reader.__init__(self, stream)
        Scanner.__init__(self)
        Parser.__init__(self)
        Composer.__init__(self)
        BaseConstructor.__init__(self)
        BaseResolver.__init__(self)

class SafeLoader(Reader, Scanner, Parser, Composer, SafeConstructor, Resolver):

    def __init__(self, stream):
        Reader.__init__(self, stream)
        Scanner.__init__(self)
        Parser.__init__(self)
        Composer.__init__(self)
        SafeConstructor.__init__(self)
        Resolver.__init__(self)

class Loader(Reader, Scanner, Parser, Composer, Constructor, Resolver):

    def __init__(self, stream):
        Reader.__init__(self, stream)
        Scanner.__init__(self)
        Parser.__init__(self)
        Composer.__init__(self)
        Constructor.__init__(self)
        Resolver.__init__(self)

