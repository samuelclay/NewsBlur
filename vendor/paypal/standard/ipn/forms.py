#!/usr/bin/env python
# -*- coding: utf-8 -*-
from vendor.paypal.standard.forms import PayPalStandardBaseForm
from vendor.paypal.standard.ipn.models import PayPalIPN


class PayPalIPNForm(PayPalStandardBaseForm):
    """
    Form used to receive and record PayPal IPN notifications.
    
    PayPal IPN test tool:
    https://developer.paypal.com/us/cgi-bin/devscr?cmd=_tools-session
    """

    class Meta:
        model = PayPalIPN
        fields = "__all__"
