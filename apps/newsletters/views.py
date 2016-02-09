from django.http import HttpResponse, Http404

def newsletter_receive(request):
    print request.REQUEST
    response = HttpResponse('OK')
    return response