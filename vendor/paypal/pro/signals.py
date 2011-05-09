from django.dispatch import Signal

"""
These signals are different from IPN signals in that they are sent the second
the payment is failed or succeeds and come with the `item` object passed to
PayPalPro rather than an IPN object.

### SENDER is the item? is that right???

"""

# Sent when a payment is successfully processed.
payment_was_successful = Signal() #providing_args=["item"])

# Sent when a payment is flagged.
payment_was_flagged = Signal() #providing_args=["item"])
