from django.contrib.auth.decorators import login_required
from django.views.decorators.http import require_POST
from utils import json

@login_required
@require_POST
@json.json_view
def set_preference(request):
    code = 1
    preference_name = request.POST['preference']
    preference_value = request.POST['value']
    
    preferences = json.decode(request.user.profile.preferences)
    preferences[preference_name] = preference_value
    request.user.profile.preferences = json.encode(preferences)
    request.user.profile.save()
    
    response = dict(code=code)
    return response

@login_required
@json.json_view
def get_preference(request):
    code = 1
    preference_name = request.POST['preference']
    preferences = json.decode(request.user.profile.preferences)
    
    response = dict(code=code, payload=preferences.get(preference_name))
    return response
    
@login_required
@require_POST
@json.json_view
def set_view_setting(request):
    code = 1
    feed_id = request.POST['feed_id']
    feed_view_setting = request.POST['feed_view_setting']
    
    view_settings = json.decode(request.user.profile.view_settings)
    view_settings[feed_id] = feed_view_setting
    request.user.profile.view_settings = json.encode(view_settings)
    request.user.profile.save()
    
    response = dict(code=code)
    return response

@login_required
@json.json_view
def get_view_setting(request):
    code = 1
    feed_id = request.POST['feed_id']
    view_settings = json.decode(request.user.profile.view_settings)
    
    response = dict(code=code, payload=view_settings.get(feed_id))
    return response
    

@login_required
@require_POST
@json.json_view
def set_collapsed_folders(request):
    code = 1
    collapsed_folders = request.POST['collapsed_folders']
    
    request.user.profile.collapsed_folders = collapsed_folders
    request.user.profile.save()
    
    response = dict(code=code)
    return response