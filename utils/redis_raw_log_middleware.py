from django.core.exceptions import MiddlewareNotUsed
from django.conf import settings
from django.db import connection
from redis.connection import Connection
from redis.client import Redis, Pipeline
from time import time
from pprint import pprint

class RedisDumpMiddleware(object):  

    def __init__(self, get_response=None):
        self.get_response = get_response

    def activated(self, request):
        return (settings.DEBUG_QUERIES or 
                (hasattr(request, 'activated_segments') and
                 'db_profiler' in request.activated_segments))

    def process_view(self, request, callback, callback_args, callback_kwargs):
        if not self.activated(request): return
        if not getattr(Connection, '_logging', False):
            # save old methods
            setattr(Connection, '_logging', True)
            connection.queriesx = []
            Redis.execute_command = \
                    self._instrument(Redis.execute_command)
            Pipeline._execute_transaction = \
                    self._instrument_pipeline(Pipeline._execute_transaction)

    def process_celery(self, profiler):
        if not self.activated(profiler): return
        if not getattr(Connection, '_logging', False):
            # save old methods
            setattr(Connection, '_logging', True)
            Redis.execute_command = \
                    self._instrument(Redis.execute_command)
            Pipeline._execute_transaction = \
                    self._instrument_pipeline(Pipeline._execute_transaction)

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
            if not getattr(connection, 'queriesx', False):
                connection.queriesx = []
            connection.queriesx.append({
                message['redis_server_name']: message,
                'time': '%.6f' % duration,
            })
            return result
        return instrumented_method

    def _instrument_pipeline(self, original_method):
        def instrumented_method(*args, **kwargs):
            message = self.process_pipeline(*args, **kwargs)
            if not message:
                return original_method(*args, **kwargs)
            start = time()
            result = original_method(*args, **kwargs)
            stop = time()
            duration = stop - start
            if not getattr(connection, 'queriesx', False):
                connection.queriesx = []
            connection.queriesx.append({
                message['redis_server_name']: message,
                'time': '%.6f' % duration,
            })
            return result
        return instrumented_method
    
    def process_message(self, *args, **kwargs):
        query = []
        redis_server_name = None
        for a, arg in enumerate(args):
            if isinstance(arg, Redis):
                redis_connection = arg
                redis_server_name = redis_connection.connection_pool.connection_kwargs['host']
                if 'db-redis-user' in redis_server_name:
                    redis_server_name = 'redis_user'
                elif 'db-redis-session' in redis_server_name:
                    redis_server_name = 'redis_session'
                elif 'db-redis-story' in redis_server_name:
                    redis_server_name = 'redis_story'
                elif 'db-redis-pubsub' in redis_server_name:
                    redis_server_name = 'redis_pubsub'
                elif 'db_redis' in redis_server_name:
                    redis_server_name = 'redis_user'
                continue
            if len(str(arg)) > 100:
                arg = "[%s bytes]" % len(str(arg))
            query.append(str(arg).replace('\n', ''))
        return { 'query': f"{redis_server_name}: {' '.join(query)}", 'redis_server_name': redis_server_name }
    
    def process_pipeline(self, *args, **kwargs):
        queries = []
        redis_server_name = None
        for a, arg in enumerate(args):
            if isinstance(arg, Connection):
                continue
            if isinstance(arg, Pipeline):
                redis_connection = arg
                redis_server_name = redis_connection.connection_pool.connection_kwargs['host']
                if 'db-redis-user' in redis_server_name:
                    redis_server_name = 'redis_user'
                elif 'db-redis-session' in redis_server_name:
                    redis_server_name = 'redis_session'
                elif 'db-redis-story' in redis_server_name:
                    redis_server_name = 'redis_story'
                elif 'db-redis-pubsub' in redis_server_name:
                    redis_server_name = 'redis_pubsub'
                elif 'db_redis' in redis_server_name:
                    redis_server_name = 'redis_user'
                continue
            if not isinstance(arg, list):
                continue
            for command in arg:
                command_query = " ".join([str(c) for c in command[0]])
                queries.append(command_query)
            if len(str(arg)) > 10000:
                arg = "[%s bytes]" % len(str(arg))
            # query.append(str(arg).replace('\n', ''))
        queries_str = '\n\t\t\t\t\t\t~FC'.join(queries)
        return { 'query': f"{redis_server_name}: {queries_str}", 'redis_server_name': redis_server_name }

    def __call__(self, request):
        response = None
        if hasattr(self, 'process_request'):
            response = self.process_request(request)
        if not response:
            response = self.get_response(request)
        if hasattr(self, 'process_response'):
            response = self.process_response(request, response)

        return response
