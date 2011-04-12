#!/usr/bin/env python
# -*- coding: utf-8 -*-
from django.conf import settings


def duplicate_txn_id(ipn_obj):
    """Returns True if a record with this transaction id exists."""
    return ipn_obj._default_manager.filter(txn_id=ipn_obj.txn_id).count() > 0
    
def make_secret(form_instance, secret_fields=None):
    """
    Returns a secret for use in a EWP form or an IPN verification based on a
    selection of variables in params. Should only be used with SSL.
    
    """
    # @@@ Moved here as temporary fix to avoid dependancy on auth.models.
    from django.contrib.auth.models import get_hexdigest
    # @@@ amount is mc_gross on the IPN - where should mapping logic go?
    # @@@ amount / mc_gross is not nessecarily returned as it was sent - how to use it? 10.00 vs. 10.0
    # @@@ the secret should be based on the invoice or custom fields as well - otherwise its always the same.
    
    # Build the secret with fields availible in both PaymentForm and the IPN. Order matters.
    if secret_fields is None:
        secret_fields = ['business', 'item_name']

    data = ""
    for name in secret_fields:
        if hasattr(form_instance, 'cleaned_data'):
            if name in form_instance.cleaned_data:
                data += unicode(form_instance.cleaned_data[name])
        else:
            # Initial data passed into the constructor overrides defaults.
            if name in form_instance.initial:
                data += unicode(form_instance.initial[name])
            elif name in form_instance.fields and form_instance.fields[name].initial is not None:
                data += unicode(form_instance.fields[name].initial)

    secret = get_hexdigest('sha1', settings.SECRET_KEY, data)
    return secret

def check_secret(form_instance, secret):
    """
    Returns true if received `secret` matches expected secret for form_instance.
    Used to verify IPN.
    
    """
    # @@@ add invoice & custom
    # secret_fields = ['business', 'item_name']
    return make_secret(form_instance) == secret