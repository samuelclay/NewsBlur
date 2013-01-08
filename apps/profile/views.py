import stripe
import datetime
from django.contrib.auth.decorators import login_required
from django.views.decorators.http import require_POST
from django.contrib.auth import logout as logout_user
from django.http import HttpResponse, HttpResponseRedirect
from django.contrib.sites.models import Site
from django.contrib.auth.models import User
from django.core.urlresolvers import reverse
from django.template import RequestContext
from django.shortcuts import render_to_response
from django.core.mail import mail_admins
from django.conf import settings
from apps.profile.models import Profile, change_password, PaymentHistory
from apps.reader.models import UserSubscription
from apps.profile.forms import StripePlusPaymentForm, PLANS, DeleteAccountForm
from apps.profile.forms import ForgotPasswordForm, ForgotPasswordReturnForm
from apps.social.models import MSocialServices, MActivity, MSocialProfile
from utils import json_functions as json
from utils.user_functions import ajax_login_required
from utils.view_functions import render_to
from utils.user_functions import get_user
from utils import log as logging
from vendor.paypal.standard.forms import PayPalPaymentsForm

SINGLE_FIELD_PREFS = ('timezone','feed_pane_size','hide_mobile','send_emails',
                      'hide_getting_started', 'has_setup_feeds', 'has_found_friends',
                      'has_trained_intelligence',)
SPECIAL_PREFERENCES = ('old_password', 'new_password', 'autofollow_friends', 'dashboard_date',)

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
        elif preference_name in SPECIAL_PREFERENCES:
            if preference_name == 'autofollow_friends':
                social_services, _ = MSocialServices.objects.get_or_create(user_id=request.user.pk)
                social_services.autofollow = preference_value
                social_services.save()
            elif preference_name == 'dashboard_date':
                request.user.profile.dashboard_date = datetime.datetime.utcnow()
        else:
            if preference_value in ["true", "false"]:
                preference_value = True if preference_value == "true" else False
            preferences[preference_name] = preference_value
        if preference_name == 'intro_page':
            logging.user(request, "~FBAdvancing intro to page ~FM~SB%s" % preference_value)
            
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
    post_settings = request.POST
    
    if post_settings['username'] and request.user.username != post_settings['username']:
        try:
            User.objects.get(username__iexact=post_settings['username'])
        except User.DoesNotExist:
            request.user.username = post_settings['username']
            request.user.save()
            social_profile = MSocialProfile.get_user(request.user.pk)
            social_profile.username = post_settings['username']
            social_profile.save()
        else:
            code = -1
            message = "This username is already taken. Try something different."
    
    if request.user.email != post_settings['email']:
        if not post_settings['email'] or not User.objects.filter(email=post_settings['email']).count():
            request.user.email = post_settings['email']
            request.user.save()
        else:
            code = -2
            message = "This email is already being used by another account. Try something different."
        
    if code != -1 and (post_settings['old_password'] or post_settings['new_password']):
        code = change_password(request.user, post_settings['old_password'], post_settings['new_password'])
        if code == -3:
            message = "Your old password is incorrect."
    
    payload = {
        "username": request.user.username,
        "email": request.user.email,
        "social_profile": MSocialProfile.profile(request.user.pk)
    }
    return dict(code=code, message=message, payload=payload)
    
@ajax_login_required
@require_POST
@json.json_view
def set_view_setting(request):
    code = 1
    feed_id = request.POST['feed_id']
    feed_view_setting = request.POST.get('feed_view_setting')
    feed_order_setting = request.POST.get('feed_order_setting')
    feed_read_filter_setting = request.POST.get('feed_read_filter_setting')
    view_settings = json.decode(request.user.profile.view_settings)
    
    setting = view_settings.get(feed_id, {})
    if isinstance(setting, basestring): setting = {'v': setting}
    if feed_view_setting: setting['v'] = feed_view_setting
    if feed_order_setting: setting['o'] = feed_order_setting
    if feed_read_filter_setting: setting['r'] = feed_read_filter_setting
    
    view_settings[feed_id] = setting
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

    logging.user(request, "~FBLoading paypal/feedchooser")

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
        message = """User: %s (%s) -- Email: %s""" % (request.user.username, request.user.pk, request.user.email)
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

@login_required
def stripe_form(request):
    user = request.user
    success_updating = False
    stripe.api_key = settings.STRIPE_SECRET
    plan = int(request.GET.get('plan', 2))
    plan = PLANS[plan-1][0]
    
    if request.method == 'POST':
        zebra_form = StripePlusPaymentForm(request.POST, email=user.email)
        if zebra_form.is_valid():
            user.email = zebra_form.cleaned_data['email']
            user.save()
            
            customer = stripe.Customer.create(**{
                'card': zebra_form.cleaned_data['stripe_token'],
                'plan': zebra_form.cleaned_data['plan'],
                'email': user.email,
                'description': user.username,
            })
            
            user.profile.strip_4_digits = zebra_form.cleaned_data['last_4_digits']
            user.profile.stripe_id = customer.id
            user.profile.save()

            success_updating = True

    else:
        zebra_form = StripePlusPaymentForm(email=user.email, plan=plan)
    
    if success_updating:
        return render_to_response('reader/paypal_return.xhtml', 
                                  {}, context_instance=RequestContext(request))
        
    return render_to_response('profile/stripe_form.xhtml',
        {
          'zebra_form': zebra_form,
          'publishable': settings.STRIPE_PUBLISHABLE,
          'success_updating': success_updating,
        },
        context_instance=RequestContext(request)
    )

@render_to('reader/activities_module.xhtml')
def load_activities(request):
    user = get_user(request)
    page = max(1, int(request.REQUEST.get('page', 1)))
    activities, has_next_page = MActivity.user(user.pk, page=page)

    return {
        'activities': activities,
        'page': page,
        'has_next_page': has_next_page,
        'username': 'You',
    }

@ajax_login_required
@json.json_view
def payment_history(request):
    history = PaymentHistory.objects.filter(user=request.user)

    return {'payments': history}

@login_required
@render_to('profile/delete_account.xhtml')
def delete_account(request):
    if request.method == 'POST':
        form = DeleteAccountForm(request.POST, user=request.user)
        if form.is_valid():
            logging.user(request.user, "~SK~BC~FRDeleting ~SB%s~SN's account." %
                         request.user.username)
            request.user.profile.delete_user(confirm=True)
            logout_user(request)
            return HttpResponseRedirect(reverse('index'))
        else:
            logging.user(request.user, "~BC~FRFailed attempt to delete ~SB%s~SN's account." %
                         request.user.username)
    else:
        logging.user(request.user, "~BC~FRAttempting to delete ~SB%s~SN's account." %
                     request.user.username)
        form = DeleteAccountForm(user=request.user)

    return {
        'delete_form': form,
    }
    

@render_to('profile/forgot_password.xhtml')
def forgot_password(request):
    if request.method == 'POST':
        form = ForgotPasswordForm(request.POST)
        if form.is_valid():
            logging.user(request.user, "~BC~FRForgot password: ~SB%s" % request.POST['email'])
            try:
                user = User.objects.get(email__iexact=request.POST['email'])
            except User.MultipleObjectsReturned:
                user = User.objects.filter(email__iexact=request.POST['email'])[0]
            user.profile.send_forgot_password_email()
            return HttpResponseRedirect(reverse('index'))
        else:
            logging.user(request.user, "~BC~FRFailed forgot password: ~SB%s~SN" %
                         request.POST['email'])
    else:
        logging.user(request.user, "~BC~FRAttempting to retrieve forgotton password.")
        form = ForgotPasswordForm()

    return {
        'forgot_password_form': form,
    }
    
@login_required
@render_to('profile/forgot_password_return.xhtml')
def forgot_password_return(request):
    if request.method == 'POST':
        logging.user(request.user, "~BC~FRReseting ~SB%s~SN's password." %
                     request.user.username)
        new_password = request.POST.get('password', '')
        request.user.set_password(new_password)
        request.user.save()
        return HttpResponseRedirect(reverse('index'))
    else:
        logging.user(request.user, "~BC~FRAttempting to reset ~SB%s~SN's password." %
                     request.user.username)
        form = ForgotPasswordReturnForm()

    return {
        'forgot_password_return_form': form,
    }