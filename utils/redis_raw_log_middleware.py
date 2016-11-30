from django.core.exceptions import MiddlewareNotUsed
from django.conf import settings
from django.db import connection
from redis.connection import Connection
from time import time

class RedisDumpMiddleware(object):    
    def activated(self, request):
        return (settings.DEBUG_QUERIES or 
                (hasattr(request, 'activated_segments') and
                 'db_profiler' in request.activated_segments))
    def process_view(self, request, callback, callback_args, callback_kwargs):
        if not self.activated(request): return
        if not getattr(Connection, '_logging', False):
            # save old methods
            setattr(Connection, '_logging', True)
            Connection.pack_command = \
                    self._instrument(Connection.pack_command)
    def process_celery(self, profiler):
        if not self.activated(profiler): return
        if not getattr(Connection, '_logging', False):
            # save old methods
            setattr(Connection, '_logging', True)
            Connection.pack_command = \
                    self._instrument(Connection.pack_command)
    def process_response(self, request, response):
        # if settings.DEBUG and hasattr(self, 'orig_pack_command'):
        #     # remove instrumentation from redis
        #     setattr(Connection, '_logging', False)
        #     Connection.pack_command = \
        #             self.orig_pack_command
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
        query = []
        for a, arg in enumerate(args):
            if isinstance(arg, Connection):
                continue
            if len(str(arg)) > 100:
                arg = "[%s bytes]" % len(str(arg))
            query.append(str(arg).replace('\n', ''))
        return { 'query': ' '.join(query) }

