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

    def __init__(self, get_response=None):
        self.get_response = get_response

    def __call__(self, request):

        self.process_request(request)
        response = self.get_response(request)

        return response

