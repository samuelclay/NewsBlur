#!/usr/bin/env python
# -*- coding: utf-8 -*-
from vendor.paypal.standard.forms import PayPalStandardBaseForm
from vendor.paypal.standard.pdt.models import PayPalPDT


class PayPalPDTForm(PayPalStandardBaseForm):
    class Meta:
        model = PayPalPDT