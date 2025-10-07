from django.conf.urls import *

from apps.profile import views

urlpatterns = [
    url(r"^get_preferences?/?", views.get_preference),
    url(r"^set_preference/?", views.set_preference),
    url(r"^set_account_settings/?", views.set_account_settings),
    url(r"^get_view_setting/?", views.get_view_setting),
    url(r"^set_view_setting/?", views.set_view_setting),
    url(r"^clear_view_setting/?", views.clear_view_setting),
    url(r"^set_collapsed_folders/?", views.set_collapsed_folders),
    url(r"^paypal_form/?", views.paypal_form),
    url(r"^paypal_return/?", views.paypal_return, name="paypal-return"),
    url(r"^paypal_archive_return/?", views.paypal_archive_return, name="paypal-archive-return"),
    url(r"^paypal_pro_return/?", views.paypal_pro_return, name="paypal-pro-return"),
    url(r"^stripe_return/?", views.paypal_return, name="stripe-return"),
    url(
        r"^switch_stripe_subscription/?", views.switch_stripe_subscription, name="switch-stripe-subscription"
    ),
    url(
        r"^switch_paypal_subscription/?", views.switch_paypal_subscription, name="switch-paypal-subscription"
    ),
    url(r"^is_premium/?", views.profile_is_premium, name="profile-is-premium"),
    url(r"^is_premium_archive/?", views.profile_is_premium_archive, name="profile-is-premium-archive"),
    # url(r'^paypal_ipn/?', include('paypal.standard.ipn.urls'), name='paypal-ipn'),
    url(r"^paypal_ipn/?", views.paypal_ipn, name="paypal-ipn"),
    url(r"^paypal_webhooks/?", views.paypal_webhooks, name="paypal-webhooks"),
    url(r"^stripe_form/?", views.stripe_form, name="stripe-form"),
    url(r"^stripe_checkout/?", views.stripe_checkout, name="stripe-checkout"),
    url(r"^activities/?", views.load_activities, name="profile-activities"),
    url(r"^payment_history/?", views.payment_history, name="profile-payment-history"),
    url(r"^cancel_premium/?", views.cancel_premium, name="profile-cancel-premium"),
    url(r"^refund_premium/?", views.refund_premium, name="profile-refund-premium"),
    url(r"^never_expire_premium/?", views.never_expire_premium, name="profile-never-expire-premium"),
    url(r"^upgrade_premium/?", views.upgrade_premium, name="profile-upgrade-premium"),
    url(r"^save_ios_receipt/?", views.save_ios_receipt, name="save-ios-receipt"),
    url(r"^save_android_receipt/?", views.save_android_receipt, name="save-android-receipt"),
    url(r"^update_payment_history/?", views.update_payment_history, name="profile-update-payment-history"),
    url(r"^delete_account/?", views.delete_account, name="profile-delete-account"),
    url(r"^forgot_password_return/?", views.forgot_password_return, name="profile-forgot-password-return"),
    url(r"^forgot_password/?", views.forgot_password, name="profile-forgot-password"),
    url(r"^delete_starred_stories/?", views.delete_starred_stories, name="profile-delete-starred-stories"),
    url(r"^delete_all_sites/?", views.delete_all_sites, name="profile-delete-all-sites"),
    url(r"^email_optout/?", views.email_optout, name="profile-email-optout"),
    url(r"^ios_subscription_status/?", views.ios_subscription_status, name="profile-ios-subscription-status"),
    url(r"debug/?", views.trigger_error, name="trigger-error"),
]
