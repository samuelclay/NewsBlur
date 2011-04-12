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

# Sent when a subscription was cancelled.
subscription_cancel = Signal()

# Sent when a subscription expires.
subscription_eot = Signal()

# Sent when a subscription was modified.
subscription_modify = Signal()

# Sent when a subscription is created.
subscription_signup = Signal()