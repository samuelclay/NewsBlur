from django.http import HttpResponse
from utils import json_functions as json
from utils.user_functions import ajax_login_required

def add_site(request, token):
    print token
    return HttpResponse(token, mimetype='application/javascript')