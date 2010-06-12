from django.shortcuts import render_to_response, get_list_or_404, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.template import RequestContext
from django.views.decorators.http import require_POST
from utils import json

@login_required
@require_POST
@json.json_view
def set_preference(request):
    code = 0
    preference_name = request.POST['preference']
    preference_value = request.POST['value']
    
    view_settings = json.decode(request.user.profile.view_settings)
    view_settings[preference_name] = preference_value
    request.user.profile.view_settings = json.encode(view_settings)
    request.user.profile.save()
    
    response = dict(code=code)
    return response

@login_required
@json.json_view
def get_preference(request):
    code = 0
    payload = {}
    preference_name = request.POST['preference']
    
    payload = request.user.profile.get(preference_name)
    
    response = dict(code=code, payload=payload)
    return response