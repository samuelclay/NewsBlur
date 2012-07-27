from django.core.exceptions import MiddlewareNotUsed
from django.conf import settings
from django.db import connection
from pymongo.connection import Connection
from time import time
import struct
import bson
from bson.errors import InvalidBSON

class SqldumpMiddleware(object):
    def __init__(self):
        if not settings.DEBUG:
            raise MiddlewareNotUsed()

    def process_view(self, request, callback, callback_args, callback_kwargs):
        self._used_msg_ids = []
        if settings.DEBUG:
            # save old methods
            self.orig_send_message = \
                    Connection._send_message
            self.orig_send_message_with_response = \
                    Connection._send_message_with_response
            # instrument methods to record messages
            Connection._send_message = \
                    self._instrument(Connection._send_message)
            Connection._send_message_with_response = \
                    self._instrument(Connection._send_message_with_response)
        return None

    def process_response(self, request, response):
        if settings.DEBUG and hasattr(self, 'orig_send_message') and hasattr(self, 'orig_send_message_with_response'):
            # remove instrumentation from pymongo
            Connection._send_message = \
                    self.orig_send_message
            Connection._send_message_with_response = \
                    self.orig_send_message_with_response
        return response

    def _instrument(self, original_method):
        def instrumented_method(*args, **kwargs):
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
        2001: 'msg',
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
    except Exception, e:
        msg = 'invalid bson'
    return { 'op': op, 'collection': collection_name,
             'msg_id': msg_id, 'skip': skip, 'limit': limit,
             'query': msg }