from django.contrib.auth.decorators import login_required
from django.views.decorators.http import require_POST
from django.http import HttpResponse, HttpResponseRedirect
from django.contrib.sites.models import Site
from django.contrib.auth.models import User
from django.core.urlresolvers import reverse
from django.template import RequestContext
from django.shortcuts import render_to_response
from django.core.mail import mail_admins
from utils import json_functions as json
from vendor.paypal.standard.forms import PayPalPaymentsForm
from utils.user_functions import ajax_login_required
from apps.profile.models import Profile, change_password
from apps.reader.models import UserSubscription

SINGLE_FIELD_PREFS = ('timezone','feed_pane_size','tutorial_finished','hide_mobile','send_emails',
                      'has_trained_intelligence', 'hide_find_friends', 'hide_getting_started',)
SPECIAL_PREFERENCES = ('old_password', 'new_password',)

@ajax_login_required
@require_POST
@json.json_view
def set_preference(request):
    code = 1
    message = ''
    new_preferences = request.POST
    
    preferences = json.decode(request.user.profile.preferences)
    for preference_name, preference_value in new_preferences.items():
        if preference_value in ['true','false']: preference_value = True if preference_value == 'true' else False
        if preference_name in SINGLE_FIELD_PREFS:
            setattr(request.user.profile, preference_name, preference_value)
        else:
            if preference_value in ["true", "false"]:
                preference_value = True if preference_value == "true" else False
            preferences[preference_name] = preference_value
        
    request.user.profile.preferences = json.encode(preferences)
    request.user.profile.save()
    
    response = dict(code=code, message=message, new_preferences=new_preferences)
    return response

@ajax_login_required
@json.json_view
def get_preference(request):
    code = 1
    preference_name = request.POST.get('preference')
    preferences = json.decode(request.user.profile.preferences)
    
    payload = preferences
    if preference_name:
        payload = preferences.get(preference_name)
        
    response = dict(code=code, payload=payload)
    return response
    
@ajax_login_required
@require_POST
@json.json_view
def set_account_settings(request):
    code = 1
    message = ''
    settings = request.POST
    
    if settings['username'] and request.user.username != settings['username']:
        try:
            User.objects.get(username__iexact=settings['username'])
        except User.DoesNotExist:
            request.user.username = settings['username']
            request.user.save()
        else:
            code = -1
            message = "This username is already taken. Try something different."
    
    if request.user.email != settings['email']:
        if not User.objects.filter(email=settings['email']).count():
            request.user.email = settings['email']
            request.user.save()
        else:
            code = -2
            message = "This email is already being used by another account. Try something different."
        
    if code != -1 and (settings['old_password'] or settings['new_password']):
        code = change_password(request.user, settings['old_password'], settings['new_password'])
        if code == -3:
            message = "Your old password is incorrect."
    
    payload = {
        "username": request.user.username,
        "email": request.user.email,
    }
    return dict(code=code, message=message, payload=payload)
    
@ajax_login_required
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

@ajax_login_required
@json.json_view
def get_view_setting(request):
    code = 1
    feed_id = request.POST['feed_id']
    view_settings = json.decode(request.user.profile.view_settings)
    
    response = dict(code=code, payload=view_settings.get(feed_id))
    return response
    

@ajax_login_required
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
    domain = Site.objects.get_current().domain
    
    paypal_dict = {
        "cmd": "_xclick-subscriptions",
        "business": "samuel@ofbrooklyn.com",
        "a3": "12.00",                     # price 
        "p3": 1,                           # duration of each unit (depends on unit)
        "t3": "Y",                         # duration unit ("M for Month")
        "src": "1",                        # make payments recur
        "sra": "1",                        # reattempt payment on payment error
        "no_note": "1",                    # remove extra notes (optional)
        "item_name": "NewsBlur Premium Account",
        "notify_url": "http://%s%s" % (domain, reverse('paypal-ipn')),
        "return_url": "http://%s%s" % (domain, reverse('paypal-return')),
        "cancel_return": "http://%s%s" % (domain, reverse('index')),
        "custom": request.user.username,
    }

    # Create the instance.
    form = PayPalPaymentsForm(initial=paypal_dict, button_type="subscribe")

    # Output the button.
    return HttpResponse(form.render(), mimetype='text/html')

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
    code = 0
    retries = int(request.GET['retries'])
    profile = Profile.objects.get(user=request.user)
    
    subs = UserSubscription.objects.filter(user=request.user)
    total_subs = subs.count()
    activated_subs = subs.filter(active=True).count()
    
    if retries >= 30:
        subject = "Premium activation failed: %s (%s/%s)" % (request.user, activated_subs, total_subs)
        message = """User: %s (%s) -- Email: %s""" % (request.user.username, request.user_id, request.user.email)
        mail_admins(subject, message, fail_silently=True)
        code = -1
        request.user.profile.is_premium = True
        request.user.profile.save()
        
    return {
        'is_premium': profile.is_premium,
        'code': code,
        'activated_subs': activated_subs,
        'total_subs': total_subs,
    }
    