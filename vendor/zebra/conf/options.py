"""
Default settings for zebra
"""
import datetime
import os

from django.conf import settings as _settings


if hasattr(_settings, 'STRIPE_PUBLISHABLE'):
    STRIPE_PUBLISHABLE = getattr(_settings, 'STRIPE_PUBLISHABLE')
else:
    try:
        STRIPE_PUBLISHABLE = os.environ['STRIPE_PUBLISHABLE']
    except KeyError:
        STRIPE_PUBLISHABLE = ''

if hasattr(_settings, 'STRIPE_SECRET'):
    STRIPE_SECRET = getattr(_settings, 'STRIPE_SECRET')
else:
    try:
        STRIPE_SECRET = os.environ['STRIPE_SECRET']
    except KeyError:
        STRIPE_SECRET = ''

ZEBRA_ENABLE_APP = getattr(_settings, 'ZEBRA_ENABLE_APP', False)
ZEBRA_AUTO_CREATE_STRIPE_CUSTOMERS = getattr(_settings,
    'ZEBRA_AUTO_CREATE_STRIPE_CUSTOMERS', True)

_today = datetime.date.today()
ZEBRA_CARD_YEARS = getattr(_settings, 'ZEBRA_CARD_YEARS',
    range(_today.year, _today.year+12))
ZEBRA_CARD_YEARS_CHOICES = getattr(_settings, 'ZEBRA_CARD_YEARS_CHOICES',
    [(i,i) for i in ZEBRA_CARD_YEARS])

ZEBRA_MAXIMUM_STRIPE_CUSTOMER_LIST_SIZE = getattr(_settings,
    'ZEBRA_MAXIMUM_STRIPE_CUSTOMER_LIST_SIZE', 100)

_audit_defaults = {
    'active': 'active',
    'no_subscription': 'no_subscription',
    'past_due': 'past_due',
    'suspended': 'suspended',
    'trialing': 'trialing',
    'unpaid': 'unpaid',
    'cancelled': 'cancelled'
}

ZEBRA_AUDIT_RESULTS = getattr(_settings, 'ZEBRA_AUDIT_RESULTS', _audit_defaults)

ZEBRA_ACTIVE_STATUSES = getattr(_settings, 'ZEBRA_ACTIVE_STATUSES',
    ('active', 'past_due', 'trialing'))
ZEBRA_INACTIVE_STATUSES = getattr(_settings, 'ZEBRA_INACTIVE_STATUSES',
    ('cancelled', 'suspended', 'unpaid', 'no_subscription'))

if ZEBRA_ENABLE_APP:
    ZEBRA_CUSTOMER_MODEL = getattr(_settings, 'ZEBRA_CUSTOMER_MODEL', 'zebra.Customer')
else:
    ZEBRA_CUSTOMER_MODEL = getattr(_settings, 'ZEBRA_CUSTOMER_MODEL', None)
