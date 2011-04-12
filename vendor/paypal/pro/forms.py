#!/usr/bin/env python
# -*- coding: utf-8 -*-
from django import forms

from paypal.pro.fields import CreditCardField, CreditCardExpiryField, CreditCardCVV2Field, CountryField


class PaymentForm(forms.Form):
    """Form used to process direct payments."""
    firstname = forms.CharField(255, label="First Name")
    lastname = forms.CharField(255, label="Last Name")
    street = forms.CharField(255, label="Street Address")
    city = forms.CharField(255, label="City")
    state = forms.CharField(255, label="State")
    countrycode = CountryField(label="Country", initial="US")
    zip = forms.CharField(32, label="Postal / Zip Code")
    acct = CreditCardField(label="Credit Card Number")
    expdate = CreditCardExpiryField(label="Expiration Date")
    cvv2 = CreditCardCVV2Field(label="Card Security Code")

    def process(self, request, item):
        """Process a PayPal direct payment."""
        from paypal.pro.helpers import PayPalWPP
        wpp = PayPalWPP(request) 
        params = self.cleaned_data
        params['creditcardtype'] = self.fields['acct'].card_type
        params['expdate'] = self.cleaned_data['expdate'].strftime("%m%Y")
        params['ipaddress'] = request.META.get("REMOTE_ADDR", "")
        params.update(item)
 
        # Create single payment:
        if 'billingperiod' not in params:
            response = wpp.doDirectPayment(params)

        # Create recurring payment:
        else:
            response = wpp.createRecurringPaymentsProfile(params, direct=True)
 
        return response


class ConfirmForm(forms.Form):
    """Hidden form used by ExpressPay flow to keep track of payer information."""
    token = forms.CharField(max_length=255, widget=forms.HiddenInput())
    PayerID = forms.CharField(max_length=255, widget=forms.HiddenInput())