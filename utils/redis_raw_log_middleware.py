from django.core.exceptions import MiddlewareNotUsed
from django.conf import settings
from django.db import connection
from redis.connection import Connection
from time import time

class SqldumpMiddleware(object):
    def __init__(self):
        if not settings.DEBUG:
            raise MiddlewareNotUsed()

    def process_view(self, request, callback, callback_args, callback_kwargs):
        if settings.DEBUG:
            # save old methods
            self.orig_pack_command = \
                    Connection.pack_command
            # instrument methods to record messages
            Connection.pack_command = \
                    self._instrument(Connection.pack_command)
        return None

    def process_response(self, request, response):
        if settings.DEBUG:
            # remove instrumentation from redis
            Connection.pack_command = \
                    self.orig_pack_command
        return response

    def _instrument(self, original_method):
        def instrumented_method(*args, **kwargs):
            message = self.process_message(*args, **kwargs)
            if not message:
                return original_method(*args, **kwargs)
            start = time()
            result = original_method(*args, **kwargs)
            stop = time()
            duration = stop - start
            connection.queries.append({
                'redis': message,
                'time': '%.3f' % duration,
            })
            return result
        return instrumented_method
    
    def process_message(self, *args, **kwargs):
        query = ' '.join([str(arg) for arg in args if not isinstance(arg, Connection)])
        return { 'query': query, }