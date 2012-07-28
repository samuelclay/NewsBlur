from django.conf import settings
from utils import log as logging

class DumpRequestMiddleware:
    def process_request(self, request):
        if settings.DEBUG:
            request_items = request.REQUEST.items()
            if request_items:
                logging.debug("~BC~FK%s" % dict(request_items))