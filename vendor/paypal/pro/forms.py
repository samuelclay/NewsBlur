#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django import forms
from django.utils.translation import ugettext_lazy as _

from paypal.pro.exceptions import PayPalFailure
from paypal.pro.fields import CountryField, CreditCardCVV2Field, CreditCardExpiryField, CreditCardField
from paypal.utils import warn_untested


class PaymentForm(forms.Form):
    """Form used to process direct payments."""
    firstname = forms.CharField(max_length=255, label=_("First Name"))
    lastname = forms.CharField(max_length=255, label=_("Last Name"))
    street = forms.CharField(max_length=255, label=_("Street Address"))
    city = forms.CharField(max_length=255, label=_("City"))
    state = forms.CharField(max_length=255, label=_("State"))
    countrycode = CountryField(label=_("Country"), initial="US")
    zip = forms.CharField(max_length=32, label=_("Postal / Zip Code"))
    acct = CreditCardField(label=_("Credit Card Number"))
    expdate = CreditCardExpiryField(label=_("Expiration Date"))
    cvv2 = CreditCardCVV2Field(label=_("Card Security Code"))
    currencycode = forms.CharField(widget=forms.HiddenInput(), initial="USD")

    def process(self, request, item):
        """Process a PayPal direct payment."""
        warn_untested()
        from paypal.pro.helpers import PayPalWPP

        wpp = PayPalWPP(request)
        params = self.cleaned_data
        params['creditcardtype'] = self.fields['acct'].card_type
        params['expdate'] = self.cleaned_data['expdate'].strftime("%m%Y")
        params['ipaddress'] = request.META.get("REMOTE_ADDR", "")
        params.update(item)

        try:
            # Create single payment:
            if 'billingperiod' not in params:
                wpp.doDirectPayment(params)
            # Create recurring payment:
            else:
                wpp.createRecurringPaymentsProfile(params, direct=True)
        except PayPalFailure:
            return False
        return True


class ConfirmForm(forms.Form):
    """Hidden form used by ExpressPay flow to keep track of payer information."""
    token = forms.CharField(max_length=255, widget=forms.HiddenInput())
    PayerID = forms.CharField(max_length=255, widget=forms.HiddenInput())
