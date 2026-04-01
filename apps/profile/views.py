"""User profile views: account settings, premium billing, login/signup, and preferences.

Manages user authentication (login, signup, logout), profile settings,
premium subscription management (Stripe/PayPal), notification preferences,
and account import/export (OPML).
"""

import calendar
import datetime
import json as python_json
import re
from urllib.parse import urlencode

import dateutil
import requests
import stripe
from django.conf import settings
from django.contrib.admin.views.decorators import staff_member_required
from django.contrib.auth import login as login_user
from django.contrib.auth import logout as logout_user
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
from django.core.mail import mail_admins
from django.db.models.aggregates import Sum
from django.http import HttpResponse, HttpResponseRedirect
from django.shortcuts import get_object_or_404, render
from django.urls import reverse
from django.views.decorators.csrf import csrf_exempt, csrf_protect
from django.views.decorators.http import require_POST
from paypal.standard.forms import PayPalPaymentsForm
from paypal.standard.ipn.views import ipn as paypal_standard_ipn

from apps.analyzer.models import (
    MClassifierAuthor,
    MClassifierFeed,
    MClassifierTag,
    MClassifierText,
    MClassifierTitle,
    MClassifierUrl,
)
from apps.profile.forms import (
    PLANS,
    AccountSettingsForm,
    DeleteAccountForm,
    ForgotPasswordForm,
    ForgotPasswordReturnForm,
    RedeemCodeForm,
    StripePlusPaymentForm,
)
from apps.profile.models import (
    GooglePlayIds,
    MGiftCode,
    MRedeemedCode,
    MReferral,
    PaymentHistory,
    PaypalIds,
    Profile,
    RNewUserQueue,
)
from apps.reader.forms import LoginForm, SignupForm
from apps.reader.models import RUserStory, UserSubscription, UserSubscriptionFolders
from apps.rss_feeds.models import MStarredStory, MStarredStoryCounts
from apps.social.models import (
    MActivity,
    MSharedStory,
    MSocialProfile,
    MSocialServices,
    MSocialSubscription,
)
from utils import json_functions as json
from utils import log as logging
from utils.user_functions import ajax_login_required, get_user
from utils.view_functions import is_true, render_to
from vendor.paypalapi.exceptions import PayPalAPIResponseError

INTEGER_FIELD_PREFS = ("feed_pane_size", "days_of_unread")
SINGLE_FIELD_PREFS = (
    "timezone",
    "hide_mobile",
    "send_emails",
    "hide_getting_started",
    "has_setup_feeds",
    "has_found_friends",
    "has_trained_intelligence",
)
SPECIAL_PREFERENCES = (
    "old_password",
    "new_password",
    "autofollow_friends",
    "dashboard_date",
)


@ajax_login_required
@require_POST
@json.json_view
def set_preference(request):
    code = 1
    message = ""
    new_preferences = request.POST

    preferences = json.decode(request.user.profile.preferences)
    for preference_name, preference_value in list(new_preferences.items()):
        if preference_value in ["true", "false"]:
            preference_value = True if preference_value == "true" else False
        if preference_name in SINGLE_FIELD_PREFS:
            setattr(request.user.profile, preference_name, preference_value)
        elif preference_name in INTEGER_FIELD_PREFS:
            if (
                preference_name == "days_of_unread"
                and int(preference_value) != request.user.profile.days_of_unread
            ):
                UserSubscription.all_subs_needs_unread_recalc(request.user.pk)
            setattr(request.user.profile, preference_name, int(preference_value))
            if preference_name in preferences:
                del preferences[preference_name]
        elif preference_name in SPECIAL_PREFERENCES:
            if preference_name == "autofollow_friends":
                social_services = MSocialServices.get_user(request.user.pk)
                social_services.autofollow = preference_value
                social_services.save()
            elif preference_name == "dashboard_date":
                request.user.profile.dashboard_date = datetime.datetime.utcnow()
        else:
            if preference_value in ["true", "false"]:
                preference_value = True if preference_value == "true" else False
            preferences[preference_name] = preference_value
            if preference_name == "briefing_enabled":
                from apps.briefing.models import MBriefingPreferences

                briefing_prefs = MBriefingPreferences.get_or_create(request.user.pk)
                briefing_prefs.enabled = bool(preference_value)
                briefing_prefs.save()
        if preference_name == "intro_page":
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
    preference_name = request.POST.get("preference")
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
            login_user(request, form.get_user(), backend="django.contrib.auth.backends.ModelBackend")
            logging.user(form.get_user(), "~FG~BBOAuth Login~FW")
            return HttpResponseRedirect(request.POST["next"] or reverse("index"))

    return render(
        request,
        "accounts/login.html",
        {"form": form, "next": request.POST.get("next", "") or request.GET.get("next", "")},
    )


@csrf_exempt
def signup(request):
    form = SignupForm(prefix="signup")
    recaptcha = request.POST.get("g-recaptcha-response", None)
    recaptcha_error = None

    if settings.ENFORCE_SIGNUP_CAPTCHA:
        if not recaptcha:
            recaptcha_error = 'Please hit the "I\'m not a robot" button.'
        else:
            response = requests.post(
                "https://www.google.com/recaptcha/api/siteverify",
                {
                    "secret": settings.RECAPTCHA_SECRET_KEY,
                    "response": recaptcha,
                },
            )
            result = response.json()
            if not result["success"]:
                recaptcha_error = 'Really, please hit the "I\'m not a robot" button.'

    if request.method == "POST":
        form = SignupForm(data=request.POST, prefix="signup")
        if form.is_valid() and not recaptcha_error:
            new_user = form.save()
            login_user(request, new_user, backend="django.contrib.auth.backends.ModelBackend")
            logging.user(new_user, "~FG~SB~BBNEW SIGNUP: ~FW%s" % new_user.email)
            new_user.profile.activate_free()

            # Record referral if present
            referrer_username = request.COOKIES.get("nb_referrer") or request.POST.get("referrer")
            if referrer_username:
                try:
                    referrer = User.objects.get(username__iexact=referrer_username)
                    if referrer.pk != new_user.pk:
                        MReferral.create_referral(referrer.pk, new_user.pk, new_user.username)
                except User.DoesNotExist:
                    pass

            # Redeem gift code if present
            gift_code = request.COOKIES.get("nb_gift_code") or request.POST.get("gift_code")
            if gift_code:
                gift = MGiftCode.objects.filter(gift_code__iexact=gift_code).first()
                if gift and not gift.redeemed_date:
                    MRedeemedCode.redeem(user=new_user, gift_code=gift_code)

            response = HttpResponseRedirect(request.POST["next"] or reverse("index"))
            response.delete_cookie("nb_referrer")
            response.delete_cookie("nb_gift_code")
            return response

    referrer = request.COOKIES.get("nb_referrer") or request.GET.get("ref", "")
    gift_code = request.COOKIES.get("nb_gift_code") or request.GET.get("gift", "")

    return render(
        request,
        "accounts/signup.html",
        {
            "form": form,
            "recaptcha_error": recaptcha_error,
            "next": request.POST.get("next", ""),
            "referrer": referrer,
            "gift_code": gift_code,
        },
    )


@login_required
@csrf_protect
def redeem_code(request):
    code = request.GET.get("code", None)
    form = RedeemCodeForm(initial={"gift_code": code})

    if request.method == "POST":
        form = RedeemCodeForm(data=request.POST)
        if form.is_valid():
            gift_code = request.POST["gift_code"]
            MRedeemedCode.redeem(user=request.user, gift_code=gift_code)
            return render(request, "reader/paypal_return.xhtml")

    return render(
        request,
        "accounts/redeem_code.html",
        {"form": form, "code": request.POST.get("code", ""), "next": request.POST.get("next", "")},
    )


@ajax_login_required
@require_POST
@json.json_view
def set_account_settings(request):
    code = -1
    message = "OK"

    form = AccountSettingsForm(user=request.user, data=request.POST)
    if form.is_valid():
        form.save()
        code = 1
    else:
        message = form.errors[list(form.errors.keys())[0]][0]

    payload = {
        "username": request.user.username,
        "email": request.user.email,
        "social_profile": MSocialProfile.profile(request.user.pk),
    }
    return dict(code=code, message=message, payload=payload)


@ajax_login_required
@require_POST
@json.json_view
def set_view_setting(request):
    code = 1
    feed_id = request.POST["feed_id"]
    feed_view_setting = request.POST.get("feed_view_setting")
    feed_order_setting = request.POST.get("feed_order_setting")
    feed_read_filter_setting = request.POST.get("feed_read_filter_setting")
    feed_layout_setting = request.POST.get("feed_layout_setting")
    feed_dashboard_count_setting = request.POST.get("feed_dashboard_count_setting")
    feed_stories_discover_setting = request.POST.get("feed_stories_discover_setting")
    view_settings = json.decode(request.user.profile.view_settings)

    setting = view_settings.get(feed_id, {})
    if isinstance(setting, str):
        setting = {"v": setting}
    if feed_view_setting:
        setting["v"] = feed_view_setting
    if feed_order_setting:
        setting["o"] = feed_order_setting
    if feed_read_filter_setting:
        setting["r"] = feed_read_filter_setting
    if feed_dashboard_count_setting:
        setting["d"] = feed_dashboard_count_setting
    if feed_layout_setting:
        setting["l"] = feed_layout_setting
    if feed_stories_discover_setting:
        setting["s"] = feed_stories_discover_setting

    view_settings[feed_id] = setting
    request.user.profile.view_settings = json.encode(view_settings)
    request.user.profile.save()

    logging.user(
        request,
        "~FMView settings: %s/%s/%s/%s"
        % (feed_view_setting, feed_order_setting, feed_read_filter_setting, feed_layout_setting),
    )
    response = dict(code=code, view_settings=view_settings)
    return response


@ajax_login_required
@require_POST
@json.json_view
def clear_view_setting(request):
    code = 1
    view_setting_type = request.POST.get("view_setting_type")
    view_settings = json.decode(request.user.profile.view_settings)
    new_view_settings = {}
    removed = 0
    for feed_id, view_setting in list(view_settings.items()):
        if view_setting_type == "layout" and "l" in view_setting:
            del view_setting["l"]
            removed += 1
        if view_setting_type == "view" and "v" in view_setting:
            del view_setting["v"]
            removed += 1
        if view_setting_type == "order" and "o" in view_setting:
            del view_setting["o"]
            removed += 1
        if view_setting_type == "order" and "r" in view_setting:
            del view_setting["r"]
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
    feed_id = request.POST["feed_id"]
    view_settings = json.decode(request.user.profile.view_settings)

    response = dict(code=code, payload=view_settings.get(feed_id))
    return response


@ajax_login_required
@require_POST
@json.json_view
def set_collapsed_folders(request):
    code = 1
    collapsed_folders = request.POST.get("collapsed_folders", "[]")

    request.user.profile.collapsed_folders = collapsed_folders
    request.user.profile.save()

    logging.user(request, "~FMCollapsing folder: %s" % collapsed_folders)
    response = dict(code=code)
    return response


def paypal_ipn(request):
    try:
        return paypal_standard_ipn(request)
    except UnicodeDecodeError as e:
        # PayPal may have returned an error page with non-ASCII characters instead of a proper IPN response
        # Log comprehensive debugging info to diagnose the encoding issue
        body = request.body
        content_type = request.META.get("CONTENT_TYPE", "unknown")

        # Try various encodings to see what works
        encodings_tried = {}
        for encoding in ["utf-8", "latin-1", "iso-8859-1", "windows-1252"]:
            try:
                decoded = body.decode(encoding)
                encodings_tried[encoding] = f"SUCCESS (len={len(decoded)})"
            except Exception as decode_error:
                encodings_tried[encoding] = f"FAILED: {decode_error}"

        # Get context around the problematic byte
        error_pos = e.start if hasattr(e, "start") else 0
        context_start = max(0, error_pos - 50)
        context_end = min(len(body), error_pos + 50)
        context_bytes = body[context_start:context_end]

        logging.error(
            f"PayPal IPN UnicodeDecodeError: {e}\n"
            f"Content-Type: {content_type}\n"
            f"Body length: {len(body)} bytes\n"
            f"Error position: {error_pos}\n"
            f"Context bytes (pos {context_start}-{context_end}): {context_bytes!r}\n"
            f"Hex dump: {context_bytes.hex()}\n"
            f"Encoding attempts: {encodings_tried}\n"
            f"Full body (latin-1): {body.decode('latin-1', errors='replace')!r}"
        )
        return HttpResponse("Invalid PayPal IPN response encoding", status=400)
    except AssertionError:
        # Paypal may have sent webhooks to ipn, so redirect
        logging.user(request, f" ---> Paypal IPN to webhooks redirect: {request.body}")
        return paypal_webhooks(request)


def find_paypal_user(data, custom_field="custom_id"):
    """Find user from PayPal webhook data with fallbacks.

    Tries multiple methods to find the user:
    1. custom_id or custom field (set during subscription creation)
    2. PaypalIds lookup by subscription ID
    3. User lookup by subscriber email

    Returns None silently for non-NewsBlur webhooks (e.g., Crabigator).
    """
    resource = data.get("resource", {})

    # Try custom field first (custom_id or custom)
    custom_value = resource.get(custom_field)
    if custom_value:
        try:
            return User.objects.get(pk=int(custom_value))
        except (User.DoesNotExist, ValueError):
            pass

    # Fallback 1: Look up by subscription ID in PaypalIds
    sub_id = resource.get("id") or resource.get("billing_agreement_id")
    if sub_id:
        try:
            paypal_id = PaypalIds.objects.get(paypal_sub_id=sub_id)
            return paypal_id.user
        except PaypalIds.DoesNotExist:
            pass

    # Fallback 2: Look up by subscriber email
    subscriber = resource.get("subscriber", {})
    email = subscriber.get("email_address")
    if email:
        try:
            return User.objects.get(email__iexact=email)
        except User.DoesNotExist:
            pass

    # Only log error if there was a custom field (indicating an intended NewsBlur webhook)
    # If no custom field, this is likely a non-NewsBlur webhook (e.g., Crabigator) - ignore silently
    if custom_value:
        logging.user(
            None,
            f" ~FR~SBPayPal webhook user not found - "
            f"event_type={data.get('event_type')} "
            f"resource_id={resource.get('id')} "
            f"billing_agreement_id={resource.get('billing_agreement_id')} "
            f"subscriber_email={email} "
            f"payer_id={subscriber.get('payer_id')} "
            f"custom_field={custom_field}={custom_value}",
        )
    else:
        logging.debug(f" ---> PayPal webhook for non-NewsBlur product, ignoring: {data.get('event_type')}")

    return None


def paypal_webhooks(request):
    try:
        data = json.decode(request.body)
    except python_json.decoder.JSONDecodeError:
        # Kick it over to paypal ipn
        return paypal_standard_ipn(request)

    logging.user(request, f" ---> Paypal webhooks {data.get('event_type', '<no event_type>')} data: {data}")

    if data["event_type"] == "BILLING.SUBSCRIPTION.CREATED":
        # Don't start a subscription but save it in case the payment comes before the subscription activation
        user = find_paypal_user(data, custom_field="custom_id")
        if user:
            user.profile.store_paypal_sub_id(data["resource"]["id"], skip_save_primary=True)
    elif data["event_type"] in ["BILLING.SUBSCRIPTION.ACTIVATED", "BILLING.SUBSCRIPTION.UPDATED"]:
        user = find_paypal_user(data, custom_field="custom_id")
        if user:
            user.profile.store_paypal_sub_id(data["resource"]["id"])
            # plan_id = data['resource']['plan_id']
            # if plan_id == Profile.plan_to_paypal_plan_id('premium'):
            #     user.profile.activate_premium()
            # elif plan_id == Profile.plan_to_paypal_plan_id('archive'):
            #     user.profile.activate_archive()
            # elif plan_id == Profile.plan_to_paypal_plan_id('pro'):
            #     user.profile.activate_pro()
            # Only cancel Stripe if user hasn't already switched back to Stripe
            if user.profile.active_provider != "stripe":
                if user.profile.stripe_id:
                    user.profile.refund_prorated_stripe_payment()
                user.profile.cancel_premium_stripe()
            user.profile.setup_premium_history()
            if data["event_type"] == "BILLING.SUBSCRIPTION.ACTIVATED":
                user.profile.cancel_and_prorate_existing_paypal_subscriptions(data)
    elif data["event_type"] == "PAYMENT.SALE.COMPLETED":
        user = find_paypal_user(data, custom_field="custom")
        if user:
            user.profile.setup_premium_history()
    elif data["event_type"] == "PAYMENT.CAPTURE.REFUNDED":
        user = find_paypal_user(data, custom_field="custom_id")
        if user:
            user.profile.setup_premium_history()
    elif data["event_type"] in ["BILLING.SUBSCRIPTION.CANCELLED", "BILLING.SUBSCRIPTION.SUSPENDED"]:
        user = find_paypal_user(data, custom_field="custom_id")
        if user:
            user.profile.setup_premium_history()

    return HttpResponse("OK")


def find_google_play_user(purchase_token):
    try:
        gp_id = GooglePlayIds.objects.get(purchase_token=purchase_token)
        return gp_id.user
    except GooglePlayIds.DoesNotExist:
        return None


def find_google_play_user_by_order(order_id):
    if not order_id:
        return None
    payment = PaymentHistory.objects.filter(
        payment_identifier=order_id,
        payment_provider="android-subscription",
    ).first()
    return payment.user if payment else None


def get_google_play_subscription(purchase_token):
    if not getattr(settings, "GOOGLE_PLAY_SERVICE_ACCOUNT_INFO", None):
        logging.debug(" ---> Google Play service account not configured")
        return None

    try:
        from google.oauth2 import service_account
        from googleapiclient.discovery import build

        credentials = service_account.Credentials.from_service_account_info(
            settings.GOOGLE_PLAY_SERVICE_ACCOUNT_INFO,
            scopes=["https://www.googleapis.com/auth/androidpublisher"],
        )
        service = build("androidpublisher", "v3", credentials=credentials)
        result = (
            service.purchases()
            .subscriptionsv2()
            .get(
                packageName=settings.GOOGLE_PLAY_PACKAGE_NAME,
                token=purchase_token,
            )
            .execute()
        )
        return result
    except Exception as e:
        logging.debug(" ---> Google Play API error: %s" % e)
        return None


def handle_google_play_notification(user, notification_type, purchase_token, subscription_id):
    NOTIFICATION_NAMES = {
        1: "RECOVERED",
        2: "RENEWED",
        3: "CANCELED",
        4: "PURCHASED",
        5: "ON_HOLD",
        6: "IN_GRACE_PERIOD",
        7: "RESTARTED",
        9: "DEFERRED",
        10: "PAUSED",
        12: "REVOKED",
        13: "EXPIRED",
    }
    type_name = NOTIFICATION_NAMES.get(notification_type, "UNKNOWN(%s)" % notification_type)
    logging.user(user, "~BM~FBGoogle Play RTDN: %s for %s" % (type_name, subscription_id))

    if notification_type in (1, 2, 4, 7):
        # RECOVERED, RENEWED, PURCHASED, RESTARTED -> activate/record payment
        order_id_for_payment = None
        subscription_info = get_google_play_subscription(purchase_token)
        if subscription_info:
            order_id_for_payment = subscription_info.get("latestOrderId")

        user.profile.activate_android_premium(
            order_id=order_id_for_payment,
            product_id=subscription_id,
        )
        user.profile.active_provider = "google-play"
        user.profile.premium_renewal = True
        user.profile.save()

    elif notification_type == 3:
        # CANCELED -> keep premium until expiry but mark renewal off
        user.profile.premium_renewal = False
        user.profile.save()

    elif notification_type in (12, 13):
        # REVOKED, EXPIRED -> deactivate
        user.profile.setup_premium_history()
        if user.profile.active_provider == "google-play":
            user.profile.deactivate_premium()

    elif notification_type in (5, 6):
        # ON_HOLD, IN_GRACE_PERIOD -> keep premium active for now
        pass


@csrf_exempt
def google_play_rtdn(request):
    import base64

    try:
        envelope = json.decode(request.body)
        message_data = base64.b64decode(envelope["message"]["data"])
        notification = json.decode(message_data)
    except Exception as e:
        logging.debug(" ---> Google Play RTDN parse error: %s" % e)
        return HttpResponse("Bad Request", status=400)

    logging.debug(" ---> Google Play RTDN received: %s" % notification)

    sub_notification = notification.get("subscriptionNotification")
    if not sub_notification:
        if notification.get("testNotification"):
            logging.debug(" ---> Google Play RTDN test notification received")
        return HttpResponse("OK")

    purchase_token = sub_notification["purchaseToken"]
    notification_type = sub_notification["notificationType"]
    subscription_id = sub_notification.get("subscriptionId", "")

    logging.debug(
        " ---> Google Play RTDN type=%s subscription=%s token=%s..."
        % (notification_type, subscription_id, purchase_token[:20])
    )

    # Look up user by purchase token
    user = find_google_play_user(purchase_token)

    # Fallback: call Google Play API to get order ID and match against PaymentHistory
    if not user:
        subscription_info = get_google_play_subscription(purchase_token)
        if subscription_info:
            latest_order_id = subscription_info.get("latestOrderId", "")
            user = find_google_play_user_by_order(latest_order_id)
            if user:
                user.profile.store_google_play_ids(
                    purchase_token=purchase_token,
                    product_id=subscription_id,
                    order_id=latest_order_id,
                )

    if not user:
        logging.debug(" ---> Google Play RTDN user not found for token=%s..." % purchase_token[:20])
        return HttpResponse("OK")

    handle_google_play_notification(user, notification_type, purchase_token, subscription_id)

    return HttpResponse("OK")


def paypal_form(request):
    domain = Site.objects.get_current().domain
    if settings.DEBUG:
        domain = "73ee-71-233-245-159.ngrok.io"

    paypal_dict = {
        "cmd": "_xclick-subscriptions",
        "business": "samuel@ofbrooklyn.com",
        "a3": "12.00",  # price
        "p3": 1,  # duration of each unit (depends on unit)
        "t3": "Y",  # duration unit ("M for Month")
        "src": "1",  # make payments recur
        "sra": "1",  # reattempt payment on payment error
        "no_note": "1",  # remove extra notes (optional)
        "item_name": "NewsBlur Premium Account",
        "notify_url": "https://%s%s" % (domain, reverse("paypal-ipn")),
        "return_url": "https://%s%s" % (domain, reverse("paypal-return")),
        "cancel_return": "https://%s%s" % (domain, reverse("index")),
        "custom": request.user.username,
    }

    # Create the instance.
    form = PayPalPaymentsForm(initial=paypal_dict, button_type="subscribe")

    logging.user(request, "~FBLoading paypal/feedchooser")

    # Output the button.
    return HttpResponse(form.render(), content_type="text/html")


@login_required
def paypal_return(request):
    return render(
        request,
        "reader/paypal_return.xhtml",
        {
            "user_profile": request.user.profile,
        },
    )


@login_required
def paypal_archive_return(request):
    return render(
        request,
        "reader/paypal_archive_return.xhtml",
        {
            "user_profile": request.user.profile,
        },
    )


@login_required
def paypal_pro_return(request):
    return render(
        request,
        "reader/paypal_pro_return.xhtml",
        {
            "user_profile": request.user.profile,
        },
    )


@login_required
def activate_premium(request):
    return HttpResponseRedirect(reverse("index"))


@login_required
def activate_premium_trial(request):
    """Page that activates a premium trial and shows progress like payment returns."""
    profile = request.user.profile
    success = profile.start_premium_trial()

    if not success:
        return HttpResponseRedirect(reverse("index"))

    return render(
        request,
        "reader/premium_trial_return.xhtml",
        {
            "user_profile": profile,
        },
    )


@ajax_login_required
@json.json_view
def profile_is_premium(request):
    # Check tries
    code = 0
    retries = int(request.GET["retries"])

    subs = UserSubscription.objects.filter(user=request.user)
    total_subs = subs.count()
    activated_subs = subs.filter(active=True).count()

    if retries >= 30:
        code = -1
        if not request.user.profile.is_premium:
            subject = "Premium activation failed: %s (%s/%s)" % (request.user, activated_subs, total_subs)
            message = """User: %s (%s) -- Email: %s""" % (
                request.user.username,
                request.user.pk,
                request.user.email,
            )
            mail_admins(subject, message)
            request.user.profile.activate_premium()

    profile = Profile.objects.get(user=request.user)
    return {
        "is_premium": profile.is_premium,
        "is_premium_archive": profile.is_archive,
        "code": code,
        "activated_subs": activated_subs,
        "total_subs": total_subs,
    }


@ajax_login_required
@json.json_view
def profile_is_premium_archive(request):
    # Check tries
    code = 0
    retries = int(request.GET["retries"])

    subs = UserSubscription.objects.filter(user=request.user)
    total_subs = subs.count()
    activated_subs = subs.filter(feed__archive_subscribers__gte=1).count()

    if retries >= 30:
        code = -1
        if not request.user.profile.is_premium_archive:
            subject = "Premium archive activation failed: %s (%s/%s)" % (
                request.user,
                activated_subs,
                total_subs,
            )
            message = """User: %s (%s) -- Email: %s""" % (
                request.user.username,
                request.user.pk,
                request.user.email,
            )
            mail_admins(subject, message)
            request.user.profile.activate_archive()

    profile = Profile.objects.get(user=request.user)

    return {
        "is_premium": profile.is_premium,
        "is_premium_archive": profile.is_archive,
        "code": code,
        "activated_subs": activated_subs,
        "total_subs": total_subs,
    }


@ajax_login_required
@json.json_view
def save_ios_receipt(request):
    receipt = request.POST.get("receipt")
    product_identifier = request.POST.get("product_identifier")
    transaction_identifier = request.POST.get("transaction_identifier")

    logging.user(request, "~BM~FBSaving iOS Receipt: %s %s" % (product_identifier, transaction_identifier))

    if product_identifier == "newsblur_premium_pro":
        paid = request.user.profile.activate_ios_pro(transaction_identifier)
    elif product_identifier == "newsblur_premium_archive":
        paid = request.user.profile.activate_ios_archive(transaction_identifier)
    else:
        paid = request.user.profile.activate_ios_premium(transaction_identifier)
    if paid:
        logging.user(
            request, "~BM~FBSending iOS Receipt email: %s %s" % (product_identifier, transaction_identifier)
        )
        subject = "iOS Premium: %s (%s)" % (request.user.profile, product_identifier)
        message = """User: %s (%s) -- Email: %s, product: %s, txn: %s, receipt: %s""" % (
            request.user.username,
            request.user.pk,
            request.user.email,
            product_identifier,
            transaction_identifier,
            receipt,
        )
        # mail_admins(subject, message)
    else:
        logging.user(
            request,
            "~BM~FBNot sending iOS Receipt email, already paid: %s %s"
            % (product_identifier, transaction_identifier),
        )

    return request.user.profile


@ajax_login_required
@json.json_view
def save_android_receipt(request):
    order_id = request.POST.get("order_id")
    product_id = request.POST.get("product_id")
    purchase_token = request.POST.get("purchase_token")

    logging.user(
        request,
        "~BM~FBSaving Android Receipt: %s %s (token: %s)"
        % (product_id, order_id, "yes" if purchase_token else "no"),
    )

    if purchase_token:
        request.user.profile.store_google_play_ids(
            purchase_token=purchase_token,
            product_id=product_id,
            order_id=order_id,
        )

    paid = request.user.profile.activate_android_premium(order_id, product_id=product_id)
    if paid:
        logging.user(request, "~BM~FBSending Android Receipt email: %s %s" % (product_id, order_id))
        subject = "Android Premium: %s (%s)" % (request.user.profile, product_id)
        message = """User: %s (%s) -- Email: %s, product: %s, order: %s""" % (
            request.user.username,
            request.user.pk,
            request.user.email,
            product_id,
            order_id,
        )
        # mail_admins(subject, message)
    else:
        logging.user(
            request, "~BM~FBNot sending Android Receipt email, already paid: %s %s" % (product_id, order_id)
        )

    return request.user.profile


@login_required
def stripe_form(request):
    user = request.user
    success_updating = False
    stripe.api_key = settings.STRIPE_SECRET
    plan = PLANS[0][0]
    renew = is_true(request.GET.get("renew", False))
    error = None

    if request.method == "POST":
        zebra_form = StripePlusPaymentForm(request.POST, email=user.email)
        if zebra_form.is_valid():
            user.email = zebra_form.cleaned_data["email"]
            user.save()
            customer = None
            current_premium = (
                user.profile.is_premium
                and user.profile.premium_expire
                and user.profile.premium_expire > datetime.datetime.now()
            )

            # Are they changing their existing card?
            if user.profile.stripe_id:
                customer = stripe.Customer.retrieve(user.profile.stripe_id)
                try:
                    card = customer.sources.create(source=zebra_form.cleaned_data["stripe_token"])
                except stripe.error.CardError:
                    error = "This card was declined."
                else:
                    customer.default_card = card.id
                    customer.save()
                    user.profile.strip_4_digits = zebra_form.cleaned_data["last_4_digits"]
                    user.profile.save()
                    user.profile.activate_premium()  # TODO: Remove, because webhooks are slow
                    success_updating = True
            else:
                try:
                    customer = stripe.Customer.create(
                        **{
                            "source": zebra_form.cleaned_data["stripe_token"],
                            "plan": zebra_form.cleaned_data["plan"],
                            "email": user.email,
                            "description": user.username,
                        }
                    )
                except stripe.error.CardError:
                    error = "This card was declined."
                else:
                    user.profile.strip_4_digits = zebra_form.cleaned_data["last_4_digits"]
                    user.profile.stripe_id = customer.id
                    user.profile.save()
                    user.profile.activate_premium()  # TODO: Remove, because webhooks are slow
                    success_updating = True

            # Check subscription to ensure latest plan, otherwise cancel it and subscribe
            if success_updating and customer and customer.subscriptions.total_count == 1:
                subscription = customer.subscriptions.data[0]
                if subscription["plan"]["id"] != "newsblur-premium-36":
                    for sub in customer.subscriptions:
                        sub.delete()
                    customer = stripe.Customer.retrieve(user.profile.stripe_id)

            if success_updating and customer and customer.subscriptions.total_count == 0:
                params = dict(
                    customer=customer.id,
                    items=[
                        {
                            "plan": "newsblur-premium-36",
                        },
                    ],
                )
                premium_expire = user.profile.premium_expire
                if current_premium and premium_expire:
                    if premium_expire < (datetime.datetime.now() + datetime.timedelta(days=365)):
                        params["billing_cycle_anchor"] = premium_expire.strftime("%s")
                        params["trial_end"] = premium_expire.strftime("%s")
                stripe.Subscription.create(**params)

    else:
        zebra_form = StripePlusPaymentForm(email=user.email, plan=plan)

    if success_updating:
        return render(request, "reader/paypal_return.xhtml")

    new_user_queue_count = RNewUserQueue.user_count()
    new_user_queue_position = RNewUserQueue.user_position(request.user.pk)
    new_user_queue_behind = 0
    if new_user_queue_position >= 0:
        new_user_queue_behind = new_user_queue_count - new_user_queue_position
        new_user_queue_position -= 1

    immediate_charge = True
    if user.profile.premium_expire and user.profile.premium_expire > datetime.datetime.now():
        immediate_charge = False

    logging.user(request, "~BM~FBLoading Stripe form")

    return render(
        request,
        "profile/stripe_form.xhtml",
        {
            "zebra_form": zebra_form,
            "publishable": settings.STRIPE_PUBLISHABLE,
            "success_updating": success_updating,
            "new_user_queue_count": new_user_queue_count - 1,
            "new_user_queue_position": new_user_queue_position,
            "new_user_queue_behind": new_user_queue_behind,
            "renew": renew,
            "immediate_charge": immediate_charge,
            "error": error,
        },
    )


@login_required
def switch_stripe_subscription(request):
    plan = request.POST.get("plan")
    if not plan:
        return HttpResponseRedirect(reverse("index"))
    if plan == "change_stripe":
        return stripe_checkout(request)
    elif plan == "change_paypal":
        paypal_url = request.user.profile.paypal_change_billing_details_url()
        return HttpResponseRedirect(paypal_url)

    switch_successful = request.user.profile.switch_stripe_subscription(plan)

    logging.user(
        request,
        "~FCSwitching subscription to ~SB%s~SN~FC (%s)"
        % (plan, "~FGsucceeded~FC" if switch_successful else "~FRfailed~FC"),
    )

    if switch_successful:
        return HttpResponseRedirect(reverse("stripe-return"))

    return stripe_checkout(request)


def switch_paypal_subscription(request):
    plan = request.POST.get("plan")
    if not plan:
        return HttpResponseRedirect(reverse("index"))
    if plan == "change_stripe":
        return stripe_checkout(request)
    elif plan == "change_paypal":
        paypal_url = request.user.profile.paypal_change_billing_details_url()
        return HttpResponseRedirect(paypal_url)

    approve_url = request.user.profile.switch_paypal_subscription_approval_url(plan)

    logging.user(
        request,
        "~FCSwitching subscription to ~SB%s~SN~FC (%s)"
        % (plan, "~FGsucceeded~FC" if approve_url else "~FRfailed~FC"),
    )

    if approve_url:
        return HttpResponseRedirect(approve_url)

    paypal_return = reverse("paypal-return")
    if plan == "archive":
        paypal_return = reverse("paypal-archive-return")
    return HttpResponseRedirect(paypal_return)


@login_required
def stripe_checkout(request):
    stripe.api_key = settings.STRIPE_SECRET
    domain = Site.objects.get_current().domain
    plan = request.POST.get("plan")
    if not plan:
        return HttpResponseRedirect(reverse("index"))

    if plan == "change_stripe":
        checkout_session = stripe.billing_portal.Session.create(
            customer=request.user.profile.stripe_id,
            return_url="https://%s%s?next=payments" % (domain, reverse("index")),
        )
        return HttpResponseRedirect(checkout_session.url, status=303)

    price = Profile.plan_to_stripe_price(plan)

    session_dict = {
        "line_items": [
            {
                "price": price,
                "quantity": 1,
            },
        ],
        "mode": "subscription",
        "metadata": {"newsblur_user_id": request.user.pk},
        "success_url": "https://%s%s" % (domain, reverse("stripe-return")),
        "cancel_url": "https://%s%s" % (domain, reverse("index")),
    }
    if request.user.profile.stripe_id:
        session_dict["customer"] = request.user.profile.stripe_id
    else:
        session_dict["customer_email"] = request.user.email

    checkout_session = stripe.checkout.Session.create(**session_dict)

    logging.user(request, "~BM~FBLoading Stripe checkout")

    return HttpResponseRedirect(checkout_session.url, status=303)


@login_required
@require_POST
def setup_usage_billing(request):
    stripe.api_key = settings.STRIPE_SECRET
    domain = Site.objects.get_current().domain

    if not settings.STRIPE_PRICE_TEXT_CLASSIFICATION or not settings.STRIPE_PRICE_IMAGE_CLASSIFICATION:
        logging.user(request, "~BR~FRStripe usage billing prices not configured")
        return HttpResponseRedirect(reverse("index"))

    session_dict = {
        "line_items": [
            {
                "price": settings.STRIPE_PRICE_TEXT_CLASSIFICATION,
            },
            {
                "price": settings.STRIPE_PRICE_IMAGE_CLASSIFICATION,
            },
        ],
        "mode": "subscription",
        "metadata": {"newsblur_user_id": request.user.pk, "purpose": "usage_billing"},
        "success_url": "https://%s%s?next=payments&usage_billing=setup_complete" % (domain, reverse("index")),
        "cancel_url": "https://%s%s?next=payments" % (domain, reverse("index")),
    }
    if request.user.profile.stripe_id:
        session_dict["customer"] = request.user.profile.stripe_id
    else:
        session_dict["customer_email"] = request.user.email

    checkout_session = stripe.checkout.Session.create(**session_dict)

    logging.user(request, "~BM~FBLoading Stripe usage billing checkout")

    return HttpResponseRedirect(checkout_session.url, status=303)


@login_required
@require_POST
def manage_usage_billing(request):
    stripe.api_key = settings.STRIPE_SECRET
    domain = Site.objects.get_current().domain

    if not request.user.profile.stripe_id:
        return HttpResponseRedirect(reverse("index"))

    portal_session = stripe.billing_portal.Session.create(
        customer=request.user.profile.stripe_id,
        return_url="https://%s%s?next=payments" % (domain, reverse("index")),
    )

    return HttpResponseRedirect(portal_session.url, status=303)


@ajax_login_required
@json.json_view
def usage_billing_history(request):
    user = request.user

    import calendar

    # Self-hosted: return local spend data without Stripe
    if user.profile.is_self_hosted_ai and not user.profile.is_usage_billing:
        current_spend, limit, is_limit_reached = user.profile.get_usage_billing_spend()
        now = datetime.datetime.utcnow()
        cycle_start = now.replace(day=1).strftime("%Y-%m-%d")
        last_day = calendar.monthrange(now.year, now.month)[1]
        cycle_end = now.replace(day=last_day).strftime("%Y-%m-%d")
        return {
            "invoices": [],
            "upcoming_invoice": None,
            "current_cycle_spend": round(current_spend, 2),
            "usage_billing_limit": float(limit) if limit else None,
            "is_limit_reached": is_limit_reached,
            "is_self_hosted": True,
            "cycle_start": cycle_start,
            "cycle_end": cycle_end,
        }

    if not user.profile.stripe_id or not user.profile.is_usage_billing:
        return {"invoices": [], "upcoming_invoice": None}

    stripe.api_key = settings.STRIPE_SECRET
    usage_price_ids = set(
        filter(None, [settings.STRIPE_PRICE_TEXT_CLASSIFICATION, settings.STRIPE_PRICE_IMAGE_CLASSIFICATION])
    )

    if not usage_price_ids:
        return {"invoices": [], "upcoming_invoice": None}

    invoices = []
    try:
        stripe_invoices = stripe.Invoice.list(customer=user.profile.stripe_id, limit=24)
        for inv in stripe_invoices.data:
            line_items = []
            is_usage_invoice = False
            for line in inv.lines.data:
                if line.price and line.price.id in usage_price_ids:
                    is_usage_invoice = True
                    line_items.append(
                        {
                            "description": line.description or line.price.nickname or "AI classifier usage",
                            "quantity": line.quantity,
                            "amount": line.amount / 100.0,
                        }
                    )
            if is_usage_invoice:
                invoices.append(
                    {
                        "date": datetime.datetime.fromtimestamp(inv.created).strftime("%Y-%m-%d"),
                        "amount": inv.amount_due / 100.0,
                        "amount_paid": inv.amount_paid / 100.0,
                        "status": inv.status,
                        "hosted_invoice_url": inv.hosted_invoice_url,
                        "invoice_number": inv.number,
                        "line_items": line_items,
                    }
                )
    except stripe.error.InvalidRequestError:
        pass

    upcoming_invoice = None
    try:
        upcoming = stripe.Invoice.upcoming(customer=user.profile.stripe_id)
        upcoming_lines = []
        is_usage = False
        for line in upcoming.lines.data:
            if line.price and line.price.id in usage_price_ids:
                is_usage = True
                upcoming_lines.append(
                    {
                        "description": line.description or line.price.nickname or "AI classifier usage",
                        "quantity": line.quantity,
                        "amount": line.amount / 100.0,
                    }
                )
        if is_usage:
            upcoming_invoice = {
                "date": datetime.datetime.fromtimestamp(upcoming.period_end).strftime("%Y-%m-%d"),
                "amount": sum(l["amount"] for l in upcoming_lines),
                "status": "upcoming",
                "line_items": upcoming_lines,
            }
    except stripe.error.InvalidRequestError:
        pass

    current_spend, limit, is_limit_reached = user.profile.get_usage_billing_spend()

    now = datetime.datetime.utcnow()
    cycle_start = now.replace(day=1).strftime("%Y-%m-%d")
    last_day = calendar.monthrange(now.year, now.month)[1]
    cycle_end = now.replace(day=last_day).strftime("%Y-%m-%d")

    return {
        "invoices": invoices,
        "upcoming_invoice": upcoming_invoice,
        "current_cycle_spend": round(current_spend, 2),
        "usage_billing_limit": float(limit) if limit else None,
        "is_limit_reached": is_limit_reached,
        "cycle_start": cycle_start,
        "cycle_end": cycle_end,
    }


@ajax_login_required
@require_POST
@json.json_view
def save_usage_billing_limit(request):
    """Save or clear the user's monthly spending limit for AI classifiers."""
    from decimal import Decimal, InvalidOperation

    from utils.llm_costs import LLMCostTracker

    user = request.user
    if not user.profile.can_use_ai_classifiers:
        return {"code": -1, "message": "Usage billing not enabled"}

    limit_str = request.POST.get("limit", "").strip()

    if not limit_str:
        user.profile.usage_billing_limit = None
        user.profile.save()
        LLMCostTracker._invalidate_limit_cache(user.pk)
        logging.user(request, "~BC~FBCleared AI classifier spending limit")
        return {"code": 1, "limit": None}

    try:
        limit = Decimal(limit_str)
    except (InvalidOperation, ValueError):
        return {"code": -1, "message": "Invalid amount"}

    if limit <= 0:
        return {"code": -1, "message": "Limit must be a positive amount"}

    if limit > 10000:
        return {"code": -1, "message": "Limit cannot exceed $10,000"}

    user.profile.usage_billing_limit = limit
    user.profile.save()
    LLMCostTracker._invalidate_limit_cache(user.pk)
    logging.user(request, "~BC~FBSet AI classifier spending limit to $%.2f" % limit)

    return {"code": 1, "limit": float(limit)}


@render_to("reader/activities_module.xhtml")
def load_activities(request):
    user = get_user(request)
    page = max(1, int(request.GET.get("page", 1)))
    activities, has_next_page = MActivity.user(user.pk, page=page)

    return {
        "activities": activities,
        "page": page,
        "has_next_page": has_next_page,
        "username": "You",
    }


@ajax_login_required
@json.json_view
def payment_history(request):
    user = request.user
    if request.user.is_staff:
        user_id = request.GET.get("user_id", request.user.pk)
        user = User.objects.get(pk=user_id)

    history = PaymentHistory.objects.filter(user=user)
    statistics = {
        "created_date": user.date_joined,
        "last_seen_date": user.profile.last_seen_on,
        "last_seen_ip": user.profile.last_seen_ip,
        "timezone": str(user.profile.timezone),
        "stripe_id": user.profile.stripe_id,
        "paypal_email": user.profile.latest_paypal_email,
        "profile": user.profile,
        "feeds": UserSubscription.objects.filter(user=user).count(),
        "email": user.email,
        "read_story_count": RUserStory.read_story_count(user.pk),
        "feed_opens": UserSubscription.objects.filter(user=user).aggregate(sum=Sum("feed_opens"))["sum"],
        "training": {
            "title_ps": MClassifierTitle.objects.filter(user_id=user.pk, score__gt=0).count(),
            "title_ng": MClassifierTitle.objects.filter(user_id=user.pk, score__lt=0).count(),
            "tag_ps": MClassifierTag.objects.filter(user_id=user.pk, score__gt=0).count(),
            "tag_ng": MClassifierTag.objects.filter(user_id=user.pk, score__lt=0).count(),
            "text_ps": MClassifierText.objects.filter(user_id=user.pk, score__gt=0).count(),
            "text_ng": MClassifierText.objects.filter(user_id=user.pk, score__lt=0).count(),
            "author_ps": MClassifierAuthor.objects.filter(user_id=user.pk, score__gt=0).count(),
            "author_ng": MClassifierAuthor.objects.filter(user_id=user.pk, score__lt=0).count(),
            "feed_ps": MClassifierFeed.objects.filter(user_id=user.pk, score__gt=0).count(),
            "feed_ng": MClassifierFeed.objects.filter(user_id=user.pk, score__lt=0).count(),
        },
    }

    next_invoice = None
    stripe_customer = user.profile.stripe_customer()
    paypal_api = user.profile.paypal_api()
    if stripe_customer:
        try:
            invoice = stripe.Invoice.upcoming(customer=stripe_customer.id)
            for lines in invoice.lines.data:
                next_invoice = dict(
                    payment_date=datetime.datetime.fromtimestamp(lines.period.start),
                    payment_amount=invoice.amount_due / 100.0,
                    payment_provider="(scheduled)",
                    scheduled=True,
                )
                break
        except stripe.error.InvalidRequestError:
            pass

    if paypal_api and not next_invoice and user.profile.premium_renewal and len(history):
        next_invoice = dict(
            payment_date=history[0].payment_date + dateutil.relativedelta.relativedelta(years=1),
            payment_amount=history[0].payment_amount,
            payment_provider="(scheduled)",
            scheduled=True,
        )

    return {
        "is_premium": user.profile.is_premium,
        "is_archive": user.profile.is_archive,
        "is_pro": user.profile.is_pro,
        "premium_expire": user.profile.premium_expire,
        "premium_renewal": user.profile.premium_renewal,
        "active_provider": user.profile.active_provider,
        "is_usage_billing": user.profile.is_usage_billing,
        "payments": history,
        "statistics": statistics,
        "next_invoice": next_invoice,
    }


@login_required
def invoice(request, payment_id):
    """
    Generate a printable invoice for a specific payment.
    Staff can view any invoice; regular users can only view their own.
    """
    if request.user.is_staff:
        payment = get_object_or_404(PaymentHistory, id=payment_id)
    else:
        payment = get_object_or_404(PaymentHistory, id=payment_id, user=request.user)

    invoice_number = f"NB-{payment.id:08d}"

    # Calculate coverage period (1 year from payment date)
    coverage_start = payment.payment_date
    coverage_end = coverage_start + dateutil.relativedelta.relativedelta(years=1)

    return render(
        request,
        "profile/invoice.xhtml",
        {
            "payment": payment,
            "invoice_number": invoice_number,
            "user": payment.user,
            "coverage_start": coverage_start,
            "coverage_end": coverage_end,
        },
    )


@ajax_login_required
@json.json_view
def cancel_premium(request):
    canceled = request.user.profile.cancel_premium()

    return {
        "code": 1 if canceled else -1,
    }


@staff_member_required
@ajax_login_required
@json.json_view
def refund_premium(request):
    user_id = request.POST.get("user_id")
    partial = request.POST.get("partial", False)
    provider = request.POST.get("provider", None)
    user = User.objects.get(pk=user_id)
    try:
        refunded = user.profile.refund_premium(partial=partial, provider=provider)
    except stripe.error.InvalidRequestError as e:
        refunded = e
    except PayPalAPIResponseError as e:
        refunded = e

    return {"code": 1 if type(refunded) == int else -1, "refunded": refunded}


@staff_member_required
@ajax_login_required
@json.json_view
def upgrade_premium(request):
    user_id = request.POST.get("user_id")
    user = User.objects.get(pk=user_id)

    gift = MGiftCode.add(gifting_user_id=User.objects.get(username="samuel").pk, receiving_user_id=user.pk)
    MRedeemedCode.redeem(user, gift.gift_code)

    return {"code": user.profile.is_premium}


@staff_member_required
@ajax_login_required
@json.json_view
def never_expire_premium(request):
    user_id = request.POST.get("user_id")
    years = int(request.POST.get("years", 0))
    user = User.objects.get(pk=user_id)
    if user.profile.is_premium:
        if years:
            user.profile.premium_expire = datetime.datetime.now() + datetime.timedelta(days=365 * years)
        else:
            user.profile.premium_expire = None
        user.profile.save()
        return {"code": 1}

    return {"code": -1}


@staff_member_required
@ajax_login_required
@json.json_view
def update_payment_history(request):
    user_id = request.POST.get("user_id")
    user = User.objects.get(pk=user_id)
    user.profile.setup_premium_history(set_premium_expire=False)

    return {"code": 1}


@login_required
@render_to("profile/delete_account.xhtml")
def delete_account(request):
    if request.method == "POST":
        form = DeleteAccountForm(request.POST, user=request.user)
        if form.is_valid():
            logging.user(request.user, "~SK~BC~FRDeleting ~SB%s~SN's account." % request.user.username)
            request.user.profile.delete_user(confirm=True)
            logout_user(request)
            return HttpResponseRedirect(reverse("index"))
        else:
            logging.user(
                request.user, "~BC~FRFailed attempt to delete ~SB%s~SN's account." % request.user.username
            )
    else:
        logging.user(request.user, "~BC~FRAttempting to delete ~SB%s~SN's account." % request.user.username)
        form = DeleteAccountForm(user=request.user)

    return {
        "delete_form": form,
    }


@render_to("profile/forgot_password.xhtml")
def forgot_password(request):
    if request.method == "POST":
        form = ForgotPasswordForm(request.POST)
        if form.is_valid():
            logging.user(request.user, "~BC~FRForgot password: ~SB%s" % request.POST["email"])
            try:
                user = User.objects.get(email__iexact=request.POST["email"])
            except User.MultipleObjectsReturned:
                user = User.objects.filter(email__iexact=request.POST["email"])[0]
            user.profile.send_forgot_password_email()
            return HttpResponseRedirect(reverse("index"))
        else:
            logging.user(request.user, "~BC~FRFailed forgot password: ~SB%s~SN" % request.POST.get("email"))
    else:
        logging.user(request.user, "~BC~FRAttempting to retrieve forgotton password.")
        form = ForgotPasswordForm()

    return {
        "forgot_password_form": form,
    }


@login_required
@render_to("profile/forgot_password_return.xhtml")
def forgot_password_return(request):
    if request.method == "POST":
        logging.user(request.user, "~BC~FRReseting ~SB%s~SN's password." % request.user.username)
        new_password = request.POST.get("password", "")
        request.user.set_password(new_password)
        request.user.save()
        return HttpResponseRedirect(reverse("index"))
    else:
        logging.user(request.user, "~BC~FRAttempting to reset ~SB%s~SN's password." % request.user.username)
        form = ForgotPasswordReturnForm()

    return {
        "forgot_password_return_form": form,
    }


@ajax_login_required
@json.json_view
def delete_starred_stories(request):
    timestamp = request.POST.get("timestamp", None)
    if timestamp:
        delete_date = datetime.datetime.fromtimestamp(int(timestamp))
    else:
        delete_date = datetime.datetime.now()
    starred_stories = MStarredStory.objects.filter(user_id=request.user.pk, starred_date__lte=delete_date)
    stories_deleted = starred_stories.count()
    starred_stories.delete()

    MStarredStoryCounts.count_for_user(request.user.pk, total_only=True)
    starred_counts, starred_count = MStarredStoryCounts.user_counts(request.user.pk, include_total=True)

    logging.user(
        request.user,
        "~BC~FRDeleting %s/%s starred stories (%s)"
        % (stories_deleted, stories_deleted + starred_count, delete_date),
    )

    return dict(
        code=1, stories_deleted=stories_deleted, starred_counts=starred_counts, starred_count=starred_count
    )


@ajax_login_required
@json.json_view
def count_starred_stories(request):
    timestamp = request.POST.get("timestamp", None)
    if timestamp:
        delete_date = datetime.datetime.fromtimestamp(int(timestamp))
    else:
        delete_date = datetime.datetime.now()
    count = MStarredStory.objects.filter(user_id=request.user.pk, starred_date__lte=delete_date).count()
    return dict(code=1, count=count)


@ajax_login_required
@json.json_view
def count_shared_stories(request):
    timestamp = request.POST.get("timestamp", None)
    if timestamp:
        delete_date = datetime.datetime.fromtimestamp(int(timestamp))
    else:
        delete_date = datetime.datetime.now()
    count = MSharedStory.objects.filter(user_id=request.user.pk, shared_date__lte=delete_date).count()
    return dict(code=1, count=count)


@ajax_login_required
@json.json_view
def delete_shared_stories(request):
    timestamp = request.POST.get("timestamp", None)
    if timestamp:
        delete_date = datetime.datetime.fromtimestamp(int(timestamp))
    else:
        delete_date = datetime.datetime.now()

    shared_stories = MSharedStory.objects.filter(user_id=request.user.pk, shared_date__lte=delete_date)
    stories_deleted = shared_stories.count()

    # Mark social subscriptions for unread recalculation
    socialsubs = MSocialSubscription.objects.filter(
        subscription_user_id=request.user.pk, needs_unread_recalc=False
    )
    for socialsub in socialsubs:
        socialsub.needs_unread_recalc = True
        socialsub.save()

    # Delete each story (triggers cleanup: removes from Redis, removes activity)
    for story in shared_stories:
        story.delete()

    # Update shared stories count in profile
    try:
        profile = MSocialProfile.objects.get(user_id=request.user.pk)
        profile.count_follows()
        shared_stories_count = profile.shared_stories_count
    except MSocialProfile.DoesNotExist:
        shared_stories_count = 0

    logging.user(
        request.user,
        "~BC~FRDeleting %s/%s shared stories (%s)"
        % (stories_deleted, stories_deleted + shared_stories_count, delete_date),
    )

    return dict(code=1, stories_deleted=stories_deleted, shared_stories_count=shared_stories_count)


@ajax_login_required
@json.json_view
def count_classifiers(request):
    user_id = request.user.pk
    counts = {
        "title": MClassifierTitle.objects.filter(user_id=user_id, is_regex__ne=True).count(),
        "title_regex": MClassifierTitle.objects.filter(user_id=user_id, is_regex=True).count(),
        "author": MClassifierAuthor.objects.filter(user_id=user_id).count(),
        "tag": MClassifierTag.objects.filter(user_id=user_id).count(),
        "text": MClassifierText.objects.filter(user_id=user_id, is_regex__ne=True).count(),
        "text_regex": MClassifierText.objects.filter(user_id=user_id, is_regex=True).count(),
        "feed": MClassifierFeed.objects.filter(user_id=user_id).count(),
        "url": MClassifierUrl.objects.filter(user_id=user_id, is_regex__ne=True).count(),
        "url_regex": MClassifierUrl.objects.filter(user_id=user_id, is_regex=True).count(),
    }
    total = sum(counts.values())
    return dict(code=1, counts=counts, total=total)


@ajax_login_required
@json.json_view
def delete_classifiers(request):
    user_id = request.user.pk
    categories = request.POST.getlist("categories")

    classifier_map = {
        "title": (MClassifierTitle, {"is_regex__ne": True}),
        "title_regex": (MClassifierTitle, {"is_regex": True}),
        "author": (MClassifierAuthor, {}),
        "tag": (MClassifierTag, {}),
        "text": (MClassifierText, {"is_regex__ne": True}),
        "text_regex": (MClassifierText, {"is_regex": True}),
        "feed": (MClassifierFeed, {}),
        "url": (MClassifierUrl, {"is_regex__ne": True}),
        "url_regex": (MClassifierUrl, {"is_regex": True}),
    }

    total_deleted = 0
    deleted_counts = {}
    for category in categories:
        if category in classifier_map:
            model, extra_filters = classifier_map[category]
            qs = model.objects.filter(user_id=user_id, **extra_filters)
            count = qs.count()
            qs.delete()
            deleted_counts[category] = count
            total_deleted += count

    logging.user(
        request.user,
        "~BC~FRDeleting %s classifiers (%s)"
        % (total_deleted, ", ".join("%s: %s" % (k, v) for k, v in deleted_counts.items())),
    )

    return dict(code=1, total_deleted=total_deleted, deleted_counts=deleted_counts)


@ajax_login_required
@json.json_view
def delete_all_sites(request):
    request.user.profile.send_opml_export_email(
        reason="You have deleted all of your sites, so here's a backup of all of your subscriptions just in case."
    )

    subs = UserSubscription.objects.filter(user=request.user)
    sub_count = subs.count()
    subs.delete()

    usf = UserSubscriptionFolders.objects.get(user=request.user)
    usf.folders = "[]"
    usf.save()

    logging.user(request.user, "~BC~FRDeleting %s sites" % sub_count)

    return dict(code=1)


@login_required
@render_to("profile/email_optout.xhtml")
def email_optout(request):
    user = request.user
    user.profile.send_emails = False
    user.profile.save()

    return {
        "user": user,
    }


@json.json_view
def ios_subscription_status(request):
    logging.debug(" ---> iOS Subscription Status: %s" % request.body)
    data = json.decode(request.body)
    subject = "iOS Subscription Status: %s" % data.get("notification_type", "[missing]")
    message = """%s""" % (request.body)
    mail_admins(subject, message)

    return {"code": 1}


def trigger_error(request):
    logging.user(request.user, "~BR~FW~SBTriggering divison by zero")
    division_by_zero = 1 / 0
    return HttpResponseRedirect(reverse("index"))


# = Referral & Gift Views ====================================================


def referral_landing(request, username):
    try:
        referrer = User.objects.get(username__iexact=username)
    except User.DoesNotExist:
        return HttpResponseRedirect(reverse("index"))

    # Don't allow self-referral
    if request.user.is_authenticated and request.user.pk == referrer.pk:
        return HttpResponseRedirect(reverse("index"))

    response = HttpResponseRedirect("%s?ref=%s" % (reverse("welcome-signup"), referrer.username))
    response.set_cookie("nb_referrer", referrer.username, max_age=30 * 24 * 60 * 60)
    return response


@login_required
@require_POST
@json.json_view
def gift_checkout(request):
    stripe.api_key = settings.STRIPE_SECRET
    domain = Site.objects.get_current().domain
    gift_tier = request.POST.get("gift_tier", "premium")
    gift_duration = request.POST.get("gift_duration", "year")

    if gift_tier not in ("premium", "archive", "pro"):
        return {"code": -1, "message": "Invalid gift tier."}

    tier_prices = {"premium": 36, "archive": 99, "pro": 299}
    payment_amount = tier_prices[gift_tier]
    if gift_tier == "pro" and gift_duration == "month":
        payment_amount = 25
    duration_days = 365 if gift_duration == "year" else 30

    # Staff can gift for free
    if request.user.is_staff:
        gift = MGiftCode.add(
            gifting_user_id=request.user.pk,
            duration=duration_days,
            payment=0,
            gift_tier=gift_tier,
            is_staff_gift=True,
        )
        gift_url = "https://%s/gift/%s/%s/%s" % (domain, gift_tier, request.user.username, gift.gift_code)
        logging.user(
            request.user,
            "~FG~BBStaff gift created: %s tier=%s code=%s"
            % (request.user.username, gift_tier, gift.gift_code),
        )
        return {"code": 1, "gift_url": gift_url, "gift_code": gift.gift_code}

    # Create Stripe Checkout Session for one-time payment
    checkout_session = stripe.checkout.Session.create(
        line_items=[
            {
                "price_data": {
                    "currency": "usd",
                    "product_data": {
                        "name": "NewsBlur %s Gift (%s)"
                        % (gift_tier.title(), "1 year" if gift_duration == "year" else "1 month"),
                    },
                    "unit_amount": payment_amount * 100,  # Stripe uses cents
                },
                "quantity": 1,
            }
        ],
        mode="payment",
        metadata={
            "newsblur_user_id": request.user.pk,
            "purpose": "gift",
            "gift_tier": gift_tier,
            "gift_duration": gift_duration,
        },
        success_url="https://%s/?next=gift" % domain,
        cancel_url="https://%s%s" % (domain, reverse("index")),
        customer_email=request.user.email,
    )

    logging.user(request, "~BM~FBLoading Stripe gift checkout for %s" % gift_tier)

    return {"code": 1, "stripe_url": checkout_session.url}


@login_required
def gift_checkout_complete(request):
    gift_tier = request.GET.get("gift_tier", "premium")
    # The gift code is created by the stripe_checkout_session_completed webhook.
    # Find the most recent gift code for this user.
    recent_gift = (
        MGiftCode.objects.filter(gifting_user_id=request.user.pk, gift_tier=gift_tier)
        .order_by("-created_date")
        .first()
    )

    domain = Site.objects.get_current().domain
    gift_url = None
    gift_code = None
    if recent_gift:
        gift_url = "https://%s/gift/%s/%s/%s" % (
            domain,
            gift_tier,
            request.user.username,
            recent_gift.gift_code,
        )
        gift_code = recent_gift.gift_code

    return render(
        request,
        "profile/gift_checkout_complete.html",
        {
            "gift_url": gift_url,
            "gift_code": gift_code,
            "gift_tier": gift_tier,
        },
    )


def gift_redeem(request, gift_tier, username, gift_code):
    gift = MGiftCode.objects.filter(gift_code__iexact=gift_code).first()
    if not gift:
        return render(request, "profile/gift_redeem.html", {"error": "Invalid gift code."})

    # Resolve gifter username for display
    gifter_username = username
    if not gifter_username:
        try:
            gifter = User.objects.get(pk=gift.gifting_user_id)
            gifter_username = gifter.username
        except User.DoesNotExist:
            gifter_username = None

    tier_names = {"premium": "Premium", "archive": "Premium Archive", "pro": "Premium Pro"}
    tier_display = tier_names.get(gift.gift_tier, "Premium")

    if gift.redeemed_date:
        # If the current user already redeemed this gift, show them the banner again
        if request.user.is_authenticated:
            already_redeemed = MRedeemedCode.objects.filter(
                user_id=request.user.pk, gift_code__iexact=gift_code
            ).first()
            if already_redeemed:
                # Skip actual redemption, just show the banner
                pass
            else:
                return render(request, "profile/gift_redeem.html", {"error": "This gift has already been redeemed."})
        else:
            return render(request, "profile/gift_redeem.html", {"error": "This gift has already been redeemed."})
    elif gift.expires_date and gift.expires_date < datetime.datetime.now():
        return render(request, "profile/gift_redeem.html", {"error": "This gift has expired."})
    elif request.user.is_authenticated:
        MRedeemedCode.redeem(user=request.user, gift_code=gift_code)

    if request.user.is_authenticated:
        duration_days = gift.duration_days or 365
        if duration_days >= 365:
            duration_label = "%d year" % (duration_days // 365)
            if duration_days // 365 > 1:
                duration_label += "s"
        elif duration_days >= 30:
            duration_label = "%d month" % (duration_days // 30)
            if duration_days // 30 > 1:
                duration_label += "s"
        else:
            duration_label = "%d days" % duration_days
        params = urlencode(
            {
                "gift_redeemed": tier_display,
                "gift_duration": duration_label,
                "gift_from": gifter_username or "",
            }
        )
        return HttpResponseRedirect("%s?%s" % (reverse("index"), params))

    # Not logged in: redirect to signup with gift code and gifter context
    response = HttpResponseRedirect("%s?gift=%s" % (reverse("welcome-signup"), gift_code))
    response.set_cookie("nb_gift_code", gift_code, max_age=24 * 60 * 60)
    return response


@ajax_login_required
@json.json_view
def referral_data(request):
    stats = MReferral.get_referral_stats(request.user.pk)
    stats["referral_url"] = "https://%s/refer/%s" % (
        Site.objects.get_current().domain,
        request.user.username,
    )
    stats["username"] = request.user.username
    profile = request.user.profile
    if profile.is_pro:
        stats["referrer_tier"] = "pro"
    elif profile.is_archive:
        stats["referrer_tier"] = "archive"
    else:
        stats["referrer_tier"] = "premium"
    return stats


@ajax_login_required
@json.json_view
def gift_data(request):
    domain = Site.objects.get_current().domain
    gifts_sent = MGiftCode.objects.filter(gifting_user_id=request.user.pk).order_by("-created_date")
    gifts_received = MRedeemedCode.objects.filter(user_id=request.user.pk).order_by("-redeemed_date")

    return {
        "gifts_sent": [
            {
                "gift_code": g.gift_code,
                "gift_tier": getattr(g, "gift_tier", "premium"),
                "gift_url": "https://%s/gift/%s/%s/%s"
                % (domain, getattr(g, "gift_tier", "premium"), request.user.username, g.gift_code),
                "created_date": g.created_date.strftime("%Y-%m-%d") if g.created_date else None,
                "redeemed": bool(getattr(g, "redeemed_date", None)),
                "is_staff_gift": getattr(g, "is_staff_gift", False),
                "refunded": bool(getattr(g, "stripe_refund_id", None)),
            }
            for g in gifts_sent
        ],
        "gifts_received": [
            {
                "gift_code": g.gift_code,
                "redeemed_date": g.redeemed_date.strftime("%Y-%m-%d") if g.redeemed_date else None,
            }
            for g in gifts_received
        ],
    }
