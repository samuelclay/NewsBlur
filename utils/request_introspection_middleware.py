from django.conf import settings
from utils import log as logging

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
            logging.debug(" ---> ~SN~FCDB times: ~FYsql: ~SB%.3f~SNs ~SN~FMmongo: ~SB%.3f~SNs ~SN~FCredis: ~SB%.3f~SNs" % (
                request.sql_times_elapsed['sql'], 
                request.sql_times_elapsed['mongo'],
                request.sql_times_elapsed['redis'],
            ))

        return response

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
