
from contextlib import contextmanager
import sys

from mock import Mock

@contextmanager
def platform(name):
    orig = sys.platform
    sys.platform = name
    yield
    sys.platform = orig

@contextmanager
def redirected_output():
    orig = sys.stdout
    sys.stdout = Mock()
    sys.stdout.isatty = lambda: False
    yield
    sys.stdout = orig

