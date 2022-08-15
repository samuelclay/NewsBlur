from pymongo import monitoring
import logging
from django.conf import settings
from django.db import connection

class MongoCommandLogger(monitoring.CommandListener):

    def __init__(self):
        self.seen_request_ids = dict()

    def started(self, event):
        self.seen_request_ids[event.request_id] = event.command
        # logging.info("Command {0.command_name} with request id "
        #              "{0.request_id} started on server "
        #              "{0.connection_id}".format(event))

    def succeeded(self, event):
        command = self.seen_request_ids.get(event.request_id, None)
        if not command:
            logging.info(f" ---> Couldn't find mongodb command: {event}")
            return

        command_dict = dict(command)
        op = event.command_name
        collection = command_dict[op]

        command_filter = command_dict.get('filter', None)
        command_documents = command_dict.get('documents', None)
        command_indexes = command_dict.get('indexes', None)
        command_insert = command_dict.get('updates', None)
        command_update = command_dict.get('updates', None)
        command_sort = command_dict.get('sort', None)
        command_get_more = command_dict.get('getMore', None)
        if command_sort:
            command_sort = dict(command_sort)

        query = command_dict
        if command_filter:
            query = f"{command_filter}"
        elif command_documents:
            query = f"{[dict(d) for d in command_documents]}"
        elif command_indexes:
            query = f"{[dict(dict(i)['key']) for i in command_indexes]}"
        elif command_insert:
            query = f"{[dict(dict(i)['q']) for i in command_insert]}"
        elif command_update:
            query = f"{[dict(dict(i)['q']) for i in command_update]}"
        elif command_get_more and isinstance(command_get_more, dict):
            query = f"{command_get_more['collection']}"
        query_size = len(str(query))
        if query_size > 500:
            query = f"{query_size} bytes"
        if command_sort:
            query = f"{query} sort:{command_sort}"

        if op == "insert" or op == "update":
            op = f"~SB{op}"
        
        message = {
            "op": op,
            "query": query,
            "collection": collection
        }

        if not getattr(connection, 'queriesx', False):
            connection.queriesx = []
        connection.queriesx.append({
            'mongo': message,
            'time': '%.6f' % (int(event.duration_micros) / 1000000),
        })

        # logging.info("Command {0.command_name} with request id "
        #              "{0.request_id} on server {0.connection_id} "
        #              "succeeded in {0.duration_micros} "
        #              "microseconds".format(event))

    def failed(self, event):
        logging.info("Command {0.command_name} with request id "
                     "{0.request_id} on server {0.connection_id} "
                     "failed in {0.duration_micros} "
                     "microseconds".format(event))

    def activated(self, request):
        return (settings.DEBUG_QUERIES or 
                (hasattr(request, 'activated_segments') and
                 'db_profiler' in request.activated_segments))
        
    def process_celery(self, profiler):
        if not self.activated(profiler): return

        connection.queriesx = []

        return None
