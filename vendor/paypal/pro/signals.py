from __future__ import unicode_literals

from paypal.standard.signals import DeprecatedSignal

"""
These signals are different from IPN signals in that they are sent the second
the payment is failed or succeeds and come with the `item` object passed to
PayPalPro rather than an IPN object.

### SENDER is the item? is that right???

"""

# Sent when a recurring payments profile is created.
payment_profile_created = DeprecatedSignal("payment_profile_created is deprecated. Use the return value from "
                                           "createRecurringPaymentsProfile directly, or pass nvp_handler to PayPalPro")

# Sent when a payment is successfully processed.
payment_was_successful = DeprecatedSignal("payment_was_successful is deprecated. Use the return value from "
                                          "doDirectPayment, doExpressCheckoutPayment or pass nvp_handler to PayPalPro")

payment_was_flagged = DeprecatedSignal("payment_was_flagged is deprecated. It has never done anything useful")

recurring_cancel = DeprecatedSignal("recurring_cancel is deprecated. Use the return value from "
                                    "manangeRecurringPaymentsProfileStatus directly")

recurring_suspend = DeprecatedSignal("recurring_suspend is deprecated. Use the return value from "
                                     "manangeRecurringPaymentsProfileStatus directly")

recurring_reactivate = DeprecatedSignal("recurring_reactivate is deprecated. Use the return value from "
                                        "manangeRecurringPaymentsProfileStatus directly")
