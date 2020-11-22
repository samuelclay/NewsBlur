"""
Note that sometimes you will get duplicate signals emitted, depending on configuration of your systems.
If you do encounter this, you will need to add the "dispatch_uid" to your connect handlers:
http://code.djangoproject.com/wiki/Signals#Helppost_saveseemstobeemittedtwiceforeachsave

"""
from __future__ import unicode_literals

from django.dispatch import Signal

from paypal.standard.signals import DeprecatedSignal

# Sent when a validated, non-duplicated IPN is received.
valid_ipn_received = Signal()

# Sent when a flagged IPN (e.g. duplicate, invalid) is received.
invalid_ipn_received = Signal()

# Deprecated signals:

# Sent when a payment is successfully processed.
payment_was_successful = DeprecatedSignal("payment_was_successful is deprecated, "
                                          "please migrate to valid_ipn_received instead")

# Sent when a payment is flagged.
payment_was_flagged = DeprecatedSignal("payment_was_flagged is deprecated, "
                                       "please migrate to invalid_ipn_received instead")

# Sent when a payment was refunded by the seller.
payment_was_refunded = DeprecatedSignal("payment_was_refunded is deprecated, "
                                        "please migrate to valid_ipn_received instead")

# Sent when a payment was reversed by the buyer.
payment_was_reversed = DeprecatedSignal("payment_was_reversed is deprecated, "
                                        "please migrate to valid_ipn_received instead")

# Sent when a subscription was cancelled.
subscription_cancel = DeprecatedSignal("subscription_cancel is deprecated, "
                                       "please migrate to valid_ipn_received instead")

# Sent when a subscription expires.
subscription_eot = DeprecatedSignal("subscription_eot is deprecated, "
                                    "please migrate to valid_ipn_received instead")

# Sent when a subscription was modified.
subscription_modify = DeprecatedSignal("subscription_modify is deprecated, "
                                       "please migrate to valid_ipn_received instead")

# Sent when a subscription is created.
subscription_signup = DeprecatedSignal("subscription_signup is deprecated, "
                                       "please migrate to valid_ipn_received instead")

# recurring_payment_profile_created
recurring_create = DeprecatedSignal("recurring_create is deprecated, "
                                    "please migrate to valid_ipn_received instead")

# recurring_payment
recurring_payment = DeprecatedSignal("recurring_payment is deprecated, "
                                     "please migrate to valid_ipn_received instead")

recurring_cancel = DeprecatedSignal("recurring_cancel is deprecated, "
                                    "please migrate to valid_ipn_received instead")

recurring_skipped = DeprecatedSignal("recurring_skipped is deprecated, "
                                     "please migrate to valid_ipn_received instead")

recurring_failed = DeprecatedSignal("recurring_failed is deprecated, "
                                    "please migrate to valid_ipn_received instead")
