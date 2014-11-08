"""
Note that sometimes you will get duplicate signals emitted, depending on configuration of your systems.
If you do encounter this, you will need to add the "dispatch_uid" to your connect handlers:
http://code.djangoproject.com/wiki/Signals#Helppost_saveseemstobeemittedtwiceforeachsave

"""
from django.dispatch import Signal

# Sent when a payment is successfully processed.
payment_was_successful = Signal()

# Sent when a payment is flagged.
payment_was_flagged = Signal()

# Sent when a payment was refunded by the seller.
payment_was_refunded = Signal()

# Sent when a payment was reversed by the buyer.
payment_was_reversed = Signal()

# Sent when a subscription was cancelled.
subscription_cancel = Signal()

# Sent when a subscription expires.
subscription_eot = Signal()

# Sent when a subscription was modified.
subscription_modify = Signal()

# Sent when a subscription is created.
subscription_signup = Signal()

# recurring_payment_profile_created
recurring_create = Signal()

# recurring_payment
recurring_payment = Signal()

recurring_cancel = Signal()

recurring_skipped = Signal()

recurring_failed = Signal()