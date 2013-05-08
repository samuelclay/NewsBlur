import logging
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from haystack.constants import DEFAULT_ALIAS
from haystack import signals
from haystack.utils import loading


__author__ = 'Daniel Lindsley'
__version__ = (2, 0, 0, 'beta')


# Setup default logging.
log = logging.getLogger('haystack')
stream = logging.StreamHandler()
stream.setLevel(logging.INFO)
log.addHandler(stream)


# Help people clean up from 1.X.
if hasattr(settings, 'HAYSTACK_SITECONF'):
    raise ImproperlyConfigured('The HAYSTACK_SITECONF setting is no longer used & can be removed.')
if hasattr(settings, 'HAYSTACK_SEARCH_ENGINE'):
    raise ImproperlyConfigured('The HAYSTACK_SEARCH_ENGINE setting has been replaced with HAYSTACK_CONNECTIONS.')
if hasattr(settings, 'HAYSTACK_ENABLE_REGISTRATIONS'):
    raise ImproperlyConfigured('The HAYSTACK_ENABLE_REGISTRATIONS setting is no longer used & can be removed.')
if hasattr(settings, 'HAYSTACK_INCLUDE_SPELLING'):
    raise ImproperlyConfigured('The HAYSTACK_INCLUDE_SPELLING setting is now a per-backend setting & belongs in HAYSTACK_CONNECTIONS.')


# Check the 2.X+ bits.
if not hasattr(settings, 'HAYSTACK_CONNECTIONS'):
    raise ImproperlyConfigured('The HAYSTACK_CONNECTIONS setting is required.')
if DEFAULT_ALIAS not in settings.HAYSTACK_CONNECTIONS:
    raise ImproperlyConfigured("The default alias '%s' must be included in the HAYSTACK_CONNECTIONS setting." % DEFAULT_ALIAS)

# Load the connections.
connections = loading.ConnectionHandler(settings.HAYSTACK_CONNECTIONS)

# Load the router(s).
connection_router = loading.ConnectionRouter()

if hasattr(settings, 'HAYSTACK_ROUTERS'):
    if not isinstance(settings.HAYSTACK_ROUTERS, (list, tuple)):
        raise ImproperlyConfigured("The HAYSTACK_ROUTERS setting must be either a list or tuple.")

    connection_router = loading.ConnectionRouter(settings.HAYSTACK_ROUTERS)

# Setup the signal processor.
signal_processor_path = getattr(settings, 'HAYSTACK_SIGNAL_PROCESSOR', 'haystack.signals.BaseSignalProcessor')
signal_processor_class = loading.import_class(signal_processor_path)
signal_processor = signal_processor_class(connections, connection_router)


# Per-request, reset the ghetto query log.
# Probably not extraordinarily thread-safe but should only matter when
# DEBUG = True.
def reset_search_queries(**kwargs):
    for conn in connections.all():
        conn.reset_queries()


if settings.DEBUG:
    from django.core import signals as django_signals
    django_signals.request_started.connect(reset_search_queries)
