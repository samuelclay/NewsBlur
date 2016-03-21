import stripe
import datetime
from django.contrib.auth.decorators import login_required
from django.views.decorators.http import require_POST
from django.views.decorators.csrf import csrf_protect
from django.contrib.auth import logout as logout_user
from django.contrib.auth import login as login_user
from django.db.models.aggregates import Sum
from django.http import HttpResponse, HttpResponseRedirect
from django.contrib.sites.models import Site
from django.contrib.auth.models import User
from django.contrib.admin.views.decorators import staff_member_required
from django.core.urlresolvers import reverse
from django.template import RequestContext
from django.shortcuts import render_to_response
from django.core.mail import mail_admins
from django.conf import settings
from apps.profile.models import Profile, PaymentHistory, RNewUserQueue, MRedeemedCode, MGiftCode
from apps.reader.models import UserSubscription, UserSubscriptionFolders, RUserStory
from apps.profile.forms import StripePlusPaymentForm, PLANS, DeleteAccountForm
from apps.profile.forms import ForgotPasswordForm, ForgotPasswordReturnForm, AccountSettingsForm
from apps.profile.forms import RedeemCodeForm
from apps.reader.forms import SignupForm, LoginForm
from apps.rss_feeds.models import MStarredStory, MStarredStoryCounts
from apps.social.models import MSocialServices, MActivity, MSocialProfile
from apps.analyzer.models import MClassifierTitle, MClassifierAuthor, MClassifierFeed, MClassifierTag
from utils import json_functions as json
from utils.user_functions import ajax_login_required
from utils.view_functions import render_to
from utils.user_functions import get_user
from utils import log as logging
from vendor.paypalapi.exceptions import PayPalAPIResponseError
from vendor.paypal.standard.forms import PayPalPaymentsForm

SINGLE_FIELD_PREFS = ('timezone','feed_pane_size','hide_mobile','send_emails',
                      'hide_getting_started', 'has_setup_feeds', 'has_found_friends',
                      'has_trained_intelligence')
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
                social_services = MSocialServices.get_user(request.user.pk)
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
    
    logging.user(request, "~FMSaving preference: %s" % new_preferences)
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

@csrf_protect
def login(request):
    form = LoginForm()

    if request.method == "POST":
        form = LoginForm(data=request.POST)
        if form.is_valid():
            login_user(request, form.get_user())
            logging.user(form.get_user(), "~FG~BBOAuth Login~FW")
            return HttpResponseRedirect(request.POST['next'] or reverse('index'))

    return render_to_response('accounts/login.html', {
        'form': form,
        'next': request.REQUEST.get('next', "")
    }, context_instance=RequestContext(request))
    
@csrf_protect
def signup(request):
    form = SignupForm()

    if request.method == "POST":
        form = SignupForm(data=request.POST)
        if form.is_valid():
            new_user = form.save()
            login_user(request, new_user)
            logging.user(new_user, "~FG~SB~BBNEW SIGNUP: ~FW%s" % new_user.email)
            new_user.profile.activate_free()
            return HttpResponseRedirect(request.POST['next'] or reverse('index'))

    return render_to_response('accounts/signup.html', {
        'form': form,
        'next': request.REQUEST.get('next', "")
    }, context_instance=RequestContext(request))

@login_required
@csrf_protect
def redeem_code(request):
    code = request.GET.get('code', None)
    form = RedeemCodeForm(initial={'gift_code': code})

    if request.method == "POST":
        form = RedeemCodeForm(data=request.POST)
        if form.is_valid():
            gift_code = request.POST['gift_code']
            MRedeemedCode.redeem(user=request.user, gift_code=gift_code)
            return render_to_response('reader/paypal_return.xhtml', 
                                      {}, context_instance=RequestContext(request))

    return render_to_response('accounts/redeem_code.html', {
        'form': form,
        'code': request.REQUEST.get('code', ""),
        'next': request.REQUEST.get('next', "")
    }, context_instance=RequestContext(request))
    

@ajax_login_required
@require_POST
@json.json_view
def set_account_settings(request):
    code = -1
    message = 'OK'

    form = AccountSettingsForm(user=request.user, data=request.POST)
    if form.is_valid():
        form.save()
        code = 1
    else:
        message = form.errors[form.errors.keys()[0]][0]
    
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
    feed_layout_setting = request.POST.get('feed_layout_setting')
    view_settings = json.decode(request.user.profile.view_settings)
    
    setting = view_settings.get(feed_id, {})
    if isinstance(setting, basestring): setting = {'v': setting}
    if feed_view_setting: setting['v'] = feed_view_setting
    if feed_order_setting: setting['o'] = feed_order_setting
    if feed_read_filter_setting: setting['r'] = feed_read_filter_setting
    if feed_layout_setting: setting['l'] = feed_layout_setting
    
    view_settings[feed_id] = setting
    request.user.profile.view_settings = json.encode(view_settings)
    request.user.profile.save()
    
    logging.user(request, "~FMView settings: %s/%s/%s/%s" % (feed_view_setting, 
                 feed_order_setting, feed_read_filter_setting, feed_layout_setting))
    response = dict(code=code)
    return response

@ajax_login_required
@require_POST
@json.json_view
def clear_view_setting(request):
    code = 1
    view_setting_type = request.POST.get('view_setting_type')
    view_settings = json.decode(request.user.profile.view_settings)
    new_view_settings = {}
    removed = 0
    for feed_id, view_setting in view_settings.items():
        if view_setting_type == 'layout' and 'l' in view_setting:
            del view_setting['l']
            removed += 1
        if view_setting_type == 'view' and 'v' in view_setting:
            del view_setting['v']
            removed += 1
        if view_setting_type == 'order' and 'o' in view_setting:
            del view_setting['o']
            removed += 1
        if view_setting_type == 'order' and 'r' in view_setting:
            del view_setting['r']
            removed += 1
        new_view_settings[feed_id] = view_setting

    request.user.profile.view_settings = json.encode(new_view_settings)
    request.user.profile.save()
    
    logging.user(request, "~FMClearing view settings: %s (found %s)" % (view_setting_type, removed))
    response = dict(code=code, view_settings=view_settings, removed=removed)
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
    
    logging.user(request, "~FMCollapsing folder: %s" % collapsed_folders)
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
        code = -1
        if not request.user.profile.is_premium:
            subject = "Premium activation failed: %s (%s/%s)" % (request.user, activated_subs, total_subs)
            message = """User: %s (%s) -- Email: %s""" % (request.user.username, request.user.pk, request.user.email)
            mail_admins(subject, message, fail_silently=True)
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
    error = None
    
    if request.method == 'POST':
        zebra_form = StripePlusPaymentForm(request.POST, email=user.email)
        if zebra_form.is_valid():
            user.email = zebra_form.cleaned_data['email']
            user.save()
            
            current_premium = (user.profile.is_premium and 
                               user.profile.premium_expire and
                               user.profile.premium_expire > datetime.datetime.now())
            # Are they changing their existing card?
            if user.profile.stripe_id and current_premium:
                customer = stripe.Customer.retrieve(user.profile.stripe_id)
                try:
                    card = customer.cards.create(card=zebra_form.cleaned_data['stripe_token'])
                except stripe.CardError:
                    error = "This card was declined."
                else:
                    customer.default_card = card.id
                    customer.save()
                    success_updating = True
            else:
                try:
                    customer = stripe.Customer.create(**{
                        'card': zebra_form.cleaned_data['stripe_token'],
                        'plan': zebra_form.cleaned_data['plan'],
                        'email': user.email,
                        'description': user.username,
                    })
                except stripe.CardError:
                    error = "This card was declined."
                else:
                    user.profile.strip_4_digits = zebra_form.cleaned_data['last_4_digits']
                    user.profile.stripe_id = customer.id
                    user.profile.save()
                    user.profile.activate_premium() # TODO: Remove, because webhooks are slow
                    success_updating = True

    else:
        zebra_form = StripePlusPaymentForm(email=user.email, plan=plan)
    
    if success_updating:
        return render_to_response('reader/paypal_return.xhtml', 
                                  {}, context_instance=RequestContext(request))
    
    new_user_queue_count = RNewUserQueue.user_count()
    new_user_queue_position = RNewUserQueue.user_position(request.user.pk)
    new_user_queue_behind = 0
    if new_user_queue_position >= 0:
        new_user_queue_behind = new_user_queue_count - new_user_queue_position 
        new_user_queue_position -= 1
    
    logging.user(request, "~BM~FBLoading Stripe form")

    return render_to_response('profile/stripe_form.xhtml',
        {
          'zebra_form': zebra_form,
          'publishable': settings.STRIPE_PUBLISHABLE,
          'success_updating': success_updating,
          'new_user_queue_count': new_user_queue_count - 1,
          'new_user_queue_position': new_user_queue_position,
          'new_user_queue_behind': new_user_queue_behind,
          'error': error,
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
    user = request.user
    if request.user.is_staff:
        user_id = request.REQUEST.get('user_id', request.user.pk)
        user = User.objects.get(pk=user_id)

    history = PaymentHistory.objects.filter(user=user)
    statistics = {
        "created_date": user.date_joined,
        "last_seen_date": user.profile.last_seen_on,
        "last_seen_ip": user.profile.last_seen_ip,
        "timezone": unicode(user.profile.timezone),
        "stripe_id": user.profile.stripe_id,
        "profile": user.profile,
        "feeds": UserSubscription.objects.filter(user=user).count(),
        "email": user.email,
        "read_story_count": RUserStory.read_story_count(user.pk),
        "feed_opens": UserSubscription.objects.filter(user=user).aggregate(sum=Sum('feed_opens'))['sum'],
        "training": {
            'title_ps': MClassifierTitle.objects.filter(user_id=user.pk, score__gt=0).count(),
            'title_ng': MClassifierTitle.objects.filter(user_id=user.pk, score__lt=0).count(),
            'tag_ps': MClassifierTag.objects.filter(user_id=user.pk, score__gt=0).count(),
            'tag_ng': MClassifierTag.objects.filter(user_id=user.pk, score__lt=0).count(),
            'author_ps': MClassifierAuthor.objects.filter(user_id=user.pk, score__gt=0).count(),
            'author_ng': MClassifierAuthor.objects.filter(user_id=user.pk, score__lt=0).count(),
            'feed_ps': MClassifierFeed.objects.filter(user_id=user.pk, score__gt=0).count(),
            'feed_ng': MClassifierFeed.objects.filter(user_id=user.pk, score__lt=0).count(),
        }
    }
    
    return {
        'is_premium': user.profile.is_premium,
        'premium_expire': user.profile.premium_expire,
        'payments': history,
        'statistics': statistics,
    }

@ajax_login_required
@json.json_view
def cancel_premium(request):
    canceled = request.user.profile.cancel_premium()
    
    return {
        'code': 1 if canceled else -1, 
    }

@staff_member_required
@ajax_login_required
@json.json_view
def refund_premium(request):
    user_id = request.REQUEST.get('user_id')
    partial = request.REQUEST.get('partial', False)
    user = User.objects.get(pk=user_id)
    try:
        refunded = user.profile.refund_premium(partial=partial)
    except stripe.InvalidRequestError, e:
        refunded = e
    except PayPalAPIResponseError, e:
        refunded = e

    return {'code': 1 if refunded else -1, 'refunded': refunded}

@staff_member_required
@ajax_login_required
@json.json_view
def upgrade_premium(request):
    user_id = request.REQUEST.get('user_id')
    user = User.objects.get(pk=user_id)
    
    gift = MGiftCode.add(gifting_user_id=User.objects.get(username='samuel').pk, 
                         receiving_user_id=user.pk)
    MRedeemedCode.redeem(user, gift.gift_code)
    
    return {'code': user.profile.is_premium}

@staff_member_required
@ajax_login_required
@json.json_view
def never_expire_premium(request):
    user_id = request.REQUEST.get('user_id')
    user = User.objects.get(pk=user_id)
    if user.profile.is_premium:
        user.profile.premium_expire = None
        user.profile.save()
        return {'code': 1}
    
    return {'code': -1}

@staff_member_required
@ajax_login_required
@json.json_view
def update_payment_history(request):
    user_id = request.REQUEST.get('user_id')
    user = User.objects.get(pk=user_id)
    user.profile.setup_premium_history(check_premium=False)
    
    return {'code': 1}
    
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

@ajax_login_required
@json.json_view
def delete_starred_stories(request):
    timestamp = request.POST.get('timestamp', None)
    if timestamp:
        delete_date = datetime.datetime.fromtimestamp(int(timestamp))
    else:
        delete_date = datetime.datetime.now()
    starred_stories = MStarredStory.objects.filter(user_id=request.user.pk,
                                                   starred_date__lte=delete_date)
    stories_deleted = starred_stories.count()
    starred_stories.delete()

    MStarredStoryCounts.count_for_user(request.user.pk, total_only=True)
    starred_counts, starred_count = MStarredStoryCounts.user_counts(request.user.pk, include_total=True)
    
    logging.user(request.user, "~BC~FRDeleting %s/%s starred stories (%s)" % (stories_deleted,
                               stories_deleted+starred_count, delete_date))

    return dict(code=1, stories_deleted=stories_deleted, starred_counts=starred_counts,
                starred_count=starred_count)


@ajax_login_required
@json.json_view
def delete_all_sites(request):
    request.user.profile.send_opml_export_email(reason="You have deleted all of your sites, so here's a backup just in case.")
    
    subs = UserSubscription.objects.filter(user=request.user)
    sub_count = subs.count()
    subs.delete()
    
    usf = UserSubscriptionFolders.objects.get(user=request.user)
    usf.folders = '[]'
    usf.save()
    
    logging.user(request.user, "~BC~FRDeleting %s sites" % sub_count)

    return dict(code=1)


@login_required
@render_to('profile/email_optout.xhtml')
def email_optout(request):
    user = request.user
    user.profile.send_emails = False
    user.profile.save()
    
    return {
        "user": user,
    }
    