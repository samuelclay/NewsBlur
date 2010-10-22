from django.contrib.auth.decorators import login_required
from django.views.decorators.http import require_POST
from django.http import HttpResponse, HttpResponseRedirect
from django.core.urlresolvers import reverse
from django.template import RequestContext
from django.shortcuts import render_to_response
from utils import json
from paypal.standard.forms import PayPalPaymentsForm
from utils.user_functions import ajax_login_required

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

@ajax_login_required
def paypal_form(request):
    paypal_dict = {
        "cmd": "_xclick-subscriptions",
        # "business": "samuel@ofbrooklyn.com",
        "business": "samuel_1287279745_biz@conesus.com",
        "a3": "12.00",                     # price 
        "p3": 1,                           # duration of each unit (depends on unit)
        "t3": "Y",                         # duration unit ("M for Month")
        "src": "1",                        # make payments recur
        "sra": "1",                        # reattempt payment on payment error
        "no_note": "1",                    # remove extra notes (optional)
        "item_name": "NewsBlur Premium Account",
        "notify_url": reverse('paypal-ipn'),
        "return_url": reverse('paypal-return'),
        "cancel_return": reverse('index'),
        "custom": request.user.username,
    }

    # Create the instance.
    form = PayPalPaymentsForm(initial=paypal_dict, button_type="subscribe")

    # Output the button.
    return HttpResponse(form.sandbox(), mimetype='text/html')

def paypal_return(request):

    return render_to_response('reader/paypal_return.xhtml', {
    }, context_instance=RequestContext(request))
    
@login_required
def activate_premium(request):
    return HttpResponseRedirect(reverse('index'))
    
@ajax_login_required
@json.json_view
def profile_is_premium(request):
    # Check tries
    return {'is_premium': request.user.profile.is_premium}
    