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
                logging.debug(" ---> ~FC%s ~SN~FK~BC%s~BT~ST ~FC%s~BK~FC" % (request.method, request.path, dict(request_items)))
            else:
                logging.debug(" ---> ~FC%s ~SN~FK~BC%s~BT~ST" % (request.method, request.path))

    def process_response(self, request, response):
        if hasattr(request, 'sql_times_elapsed'):
            logging.debug(" ---> %s~SN~FCDB times: ~FYsql: %s%.3f~SNs ~SN~FMmongo: %s%.3f~SNs ~SN~FCredis: %s%.3f~SNs" % (
                self.elapsed_time(request),
                self.color_db(request.sql_times_elapsed['sql'], '~FY'),
                request.sql_times_elapsed['sql'], 
                self.color_db(request.sql_times_elapsed['mongo'], '~FM'),
                request.sql_times_elapsed['mongo'],
                self.color_db(request.sql_times_elapsed['redis'], '~FC'),
                request.sql_times_elapsed['redis'],
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
        if seconds >= .1:
            color = '~SB~FR'
        elif seconds > .01:
            color = '~FW'
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
