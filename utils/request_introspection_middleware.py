from django.conf import settings
from utils import log as logging

class DumpRequestMiddleware:
    def process_request(self, request):
        if settings.DEBUG:
            request_data = request.POST or request.GET
            request_items = list(request_data.items())
            # if request_items:
            logging.debug(" ---> ~FC%s ~SN~FC%s ~SN~BC~FK%s~BK~FC %s" % (request.method, request.path, dict(request_items), request.COOKIES))

    def __init__(self, get_response=None):
        self.get_response = get_response

    def __call__(self, request):

        self.process_request(request)
        response = self.get_response(request)

        return response
