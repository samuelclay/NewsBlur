from django.conf import settings
from utils import log as logging

class DumpRequestMiddleware:
    def process_request(self, request):
        if settings.DEBUG:
            request_data = request.POST or request.GET
            request_items = request_data.items()
            if request_items:
                logging.debug(" ---> ~FC%s ~SN~FC%s ~SN~BC~FK%s~BK~FC" % (request.method, request.path, dict(request_items)))
            else:
                logging.debug(" ---> ~FC%s ~SN~FC%s" % (request.method, request.path))
