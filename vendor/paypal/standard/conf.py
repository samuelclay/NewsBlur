import sys
import warnings

from django.conf import settings


class PayPalSettingsError(Exception):
    """Raised when settings be bad."""


# API Endpoints.
POSTBACK_ENDPOINT = "https://www.paypal.com/cgi-bin/webscr"
SANDBOX_POSTBACK_ENDPOINT = "https://www.sandbox.paypal.com/cgi-bin/webscr"

# Images
BUY_BUTTON_IMAGE = getattr(settings, "PAYPAL_BUY_BUTTON_IMAGE",
                           "https://www.paypal.com/en_US/i/btn/btn_buynowCC_LG.gif")
SUBSCRIPTION_BUTTON_IMAGE = getattr(settings, "PAYPAL_SUBSCRIPTION_BUTTON_IMAGE",
                             "https://www.paypal.com/en_US/i/btn/btn_subscribeCC_LG.gif")
DONATION_BUTTON_IMAGE = getattr(settings, "PAYPAL_DONATION_BUTTON_IMAGE",
                                "https://www.paypal.com/en_US/i/btn/btn_donateCC_LG.gif")


deprecated_settings = [
    ('IMAGE', 'BUY_BUTTON_IMAGE'),
    ('SUBSCRIPTION_IMAGE', 'SANDBOX_SUBSCRIPTION_BUTTON_IMAGE'),
    ('DONATION_IMAGE', 'DONATION_BUTTON_IMAGE'),
]

removed_settings = [
    'SANDBOX_IMAGE',
    'SUBSCRIPTION_SANDBOX_IMAGE',
    'DONATION_SANDBOX_IMAGE',
]

for old, new in deprecated_settings:
    old_setting = 'PAYPAL_' + old
    new_setting = 'PAYPAL_' + new
    old_setting_val = getattr(settings, old_setting, None)
    if old_setting_val is not None:
        warnings.warn(
            "Setting {0} is deprecated - use {1} instead.".format(
                old_setting, new_setting),
            DeprecationWarning)
        if hasattr(settings, new_setting):
            warnings.warn(
                "You have both old setting {0} and new setting {1} in your settings, "
                "please remove the old setting.".format(
                    old_setting, new_setting),
                DeprecationWarning)
        else:
            # use the value from the deprecated setting
            setattr(sys.modules[__name__], new, old_setting_val)

for old in removed_settings:
    old_setting = 'PAYPAL_' + old
    old_setting_val = getattr(settings, old_setting, None)
    if old_setting_val is not None:
        warnings.warn(
            "Setting {0} has been removed and is ignored.".format(old_setting),
            DeprecationWarning)


# Paypal Encrypt Certificate
PAYPAL_PRIVATE_CERT = getattr(settings, 'PAYPAL_PRIVATE_CERT', None)
PAYPAL_PUBLIC_CERT = getattr(settings, 'PAYPAL_PUBLIC_CERT', None)
PAYPAL_CERT = getattr(settings, 'PAYPAL_CERT', None)
PAYPAL_CERT_ID = getattr(settings, 'PAYPAL_CERT_ID', None)
