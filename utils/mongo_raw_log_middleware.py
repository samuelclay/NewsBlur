from django.core.exceptions import MiddlewareNotUsed
from django.conf import settings
from django.db import connection
from pymongo.mongo_client import MongoClient
from pymongo.mongo_replica_set_client import MongoReplicaSetClient
from time import time
import struct
import bson
from bson.errors import InvalidBSON

class MongoDumpMiddleware(object):    
    def activated(self, request):
        return (settings.DEBUG_QUERIES or 
                (hasattr(request, 'activated_segments') and
                 'db_profiler' in request.activated_segments))
    
    def process_view(self, request, callback, callback_args, callback_kwargs):
        if not self.activated(request): return
        self._used_msg_ids = []
        if not getattr(MongoClient, '_logging', False):
            # save old methods
            setattr(MongoClient, '_logging', True)
            MongoClient._send_message_with_response = \
                    self._instrument(MongoClient._send_message_with_response)
            MongoReplicaSetClient._send_message_with_response = \
                    self._instrument(MongoReplicaSetClient._send_message_with_response)
        return None

    def process_celery(self, profiler):
        if not self.activated(profiler): return
        self._used_msg_ids = []
        if not getattr(MongoClient, '_logging', False):
            # save old methods
            setattr(MongoClient, '_logging', True)
            MongoClient._send_message_with_response = \
                    self._instrument(MongoClient._send_message_with_response)
            MongoReplicaSetClient._send_message_with_response = \
                    self._instrument(MongoReplicaSetClient._send_message_with_response)
        return None

    def process_response(self, request, response):
        # if settings.DEBUG and hasattr(self, 'orig_send_message') and hasattr(self, 'orig_send_message_with_response'):
        #     # remove instrumentation from pymongo
        #     MongoClient._send_message = \
        #             self.orig_send_message
        #     MongoClient._send_message_with_response = \
        #             self.orig_send_message_with_response
        #     MongoReplicaSetClient._send_message = \
        #             self.orig_rs_send_message
        #     MongoReplicaSetClient._send_message_with_response = \
        #             self.orig_rs_send_message_with_response
        return response

    def _instrument(self, original_method):
        def instrumented_method(*args, **kwargs):
            # query = args[1].get_message(False, False)
            # message = _mongodb_decode_wire_protocol(query[1])
            message = _mongodb_decode_wire_protocol(args[1][1])
            if not message or message['msg_id'] in self._used_msg_ids:
                return original_method(*args, **kwargs)
            self._used_msg_ids.append(message['msg_id'])
            start = time()
            result = original_method(*args, **kwargs)
            stop = time()
            duration = stop - start
            connection.queries.append({
                'mongo': message,
                'time': '%.3f' % duration,
            })
            return result
        return instrumented_method

def _mongodb_decode_wire_protocol(message):
    """ http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol """
    MONGO_OPS = {
        1000: 'msg',
        2001: 'update',
        2002: 'insert',
        2003: 'reserved',
        2004: 'query',
        2005: 'get_more',
        2006: 'delete',
        2007: 'kill_cursors',
    }
    _, msg_id, _, opcode, _ = struct.unpack('<iiiii', message[:20])
    op = MONGO_OPS.get(opcode, 'unknown')
    zidx = 20
    collection_name_size = message[zidx:].find('\0')
    collection_name = message[zidx:zidx+collection_name_size]
    if '.system.' in collection_name:
        return
    zidx += collection_name_size + 1
    skip, limit = struct.unpack('<ii', message[zidx:zidx+8])
    zidx += 8
    msg = ""
    try:
        if message[zidx:]:
            msg = bson.decode_all(message[zidx:])
    except:
        msg = 'invalid bson'
    return { 'op': op, 'collection': collection_name,
             'msg_id': msg_id, 'skip': skip, 'limit': limit,
             'query': msg }