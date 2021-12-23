from django.conf import settings
from utils import log as logging
import time

IGNORE_PATHS = [
    "/_haproxychk",
]

class DumpRequestMiddleware:
    def process_request(self, request):
        if settings.DEBUG and request.path not in IGNORE_PATHS:
            request_data = request.POST or request.GET
            request_items = dict(request_data).items()
            if request_items:
                request_items_str = f"{dict(request_items)}"
                if len(request_items_str) > 200:
                    request_items_str = request_items_str[:100] + "...[" + str(len(request_items_str)-200) + " bytes]..." + request_items_str[-100:]
                logging.debug(" ---> ~FC%s ~SN~FK~BC%s~BT~ST ~FC%s~BK~FC" % (request.method, request.path, request_items_str))
            else:
                logging.debug(" ---> ~FC%s ~SN~FK~BC%s~BT~ST" % (request.method, request.path))

    def process_response(self, request, response):
        if hasattr(request, 'sql_times_elapsed'):
            redis_log = "~FCuser:%s%.6f~SNs ~FCstory:%s%.6f~SNs ~FCsession:%s%.6f~SNs ~FCpubsub:%s%.6f~SNs" % (
                self.color_db(request.sql_times_elapsed['redis_user'], '~FC'),
                request.sql_times_elapsed['redis_user'],
                self.color_db(request.sql_times_elapsed['redis_story'], '~FC'),
                request.sql_times_elapsed['redis_story'],
                self.color_db(request.sql_times_elapsed['redis_session'], '~FC'),
                request.sql_times_elapsed['redis_session'],
                self.color_db(request.sql_times_elapsed['redis_pubsub'], '~FC'),
                request.sql_times_elapsed['redis_pubsub'],
            )
            logging.debug(" ---> %s~SN~FCDB times: ~FYsql: %s%.4f~SNs ~SN~FMmongo: %s%.5f~SNs ~SN~FCredis: %s" % (
                self.elapsed_time(request),
                self.color_db(request.sql_times_elapsed['sql'], '~FY'),
                request.sql_times_elapsed['sql'], 
                self.color_db(request.sql_times_elapsed['mongo'], '~FM'),
                request.sql_times_elapsed['mongo'],
                redis_log
            ))

        return response

    def elapsed_time(self, request):
        time_elapsed = ""
        if hasattr(request, 'start_time'):
            seconds = time.time() - request.start_time
            color = '~FB'
            if seconds >= 1:
                color = '~FR'
            elif seconds > .2:
                color = '~SB~FK'
            time_elapsed = "[%s%.4ss~SB] " % (
                color,
                seconds,
            )
        return time_elapsed
    
    def color_db(self, seconds, default):
        color = default
        if seconds >= .25:
            color = '~SB~FR'
        elif seconds > .1:
            color = '~FW'
        elif seconds == 0:
            color = '~FK'
        return color

    def __init__(self, get_response=None):
        self.get_response = get_response

    def __call__(self, request):
        response = None
        if hasattr(self, 'process_request'):
            response = self.process_request(request)
        if not response:
            response = self.get_response(request)
        if hasattr(self, 'process_response'):
            response = self.process_response(request, response)

        return response
