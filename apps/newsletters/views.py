from django.http import HttpResponse, Http404
from utils import log as logging


def newsletter_receive(request):
    logging.debug(request.REQUEST)
    response = HttpResponse('OK')
    return response