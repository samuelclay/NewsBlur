import inspect
import logging
import sys
import warnings

logger = logging.getLogger(__name__)


def warn_untested():
    msg = ("This method (or branch) is not covered by automated tests. It is therefore very "
           "vulnerable to being accidentally broken by future versions of django-paypal. "
           "Please contribute tests to ensure future functionality!")
    warnings.warn(msg, stacklevel=2)
    f = sys._getframe(1)
    source = "{0}:{1}".format(inspect.getmodule(f).__name__,
                              f.f_lineno)
    logger.warning("{0}: {1}".format(source, msg))
