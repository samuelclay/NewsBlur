from django.conf import settings
from utils import log as logging

class DumpRequestMiddleware:
    def process_request(self, request):
        if settings.DEBUG:
            request_items = request.REQUEST.items()
            if request_items:
                logging.debug(" ---> ~FC%s ~SN~FC%s ~SN~BC~FK%s" % (request.method, request.path, dict(request_items)))