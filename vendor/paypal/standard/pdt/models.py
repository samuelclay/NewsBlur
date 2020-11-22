#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import unicode_literals

import requests
from django.conf import settings
from django.db import models
from django.http import QueryDict
from six.moves.urllib.parse import unquote_plus

from paypal.standard.conf import POSTBACK_ENDPOINT, SANDBOX_POSTBACK_ENDPOINT
from paypal.standard.models import PayPalStandardBase
from paypal.utils import warn_untested


# ### Todo: Move this logic to conf.py:
# if paypal.standard.pdt is in installed apps
# ... then check for this setting in conf.py
class PayPalSettingsError(Exception):
    """Raised when settings are incorrect."""


try:
    IDENTITY_TOKEN = settings.PAYPAL_IDENTITY_TOKEN
except:
    raise PayPalSettingsError(
        "You must set PAYPAL_IDENTITY_TOKEN in settings.py. Get this token by enabling PDT in your PayPal account.")


class PayPalPDT(PayPalStandardBase):
    format = u"<PDT: %s %s>"

    amt = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    cm = models.CharField(max_length=255, blank=True)
    sig = models.CharField(max_length=255, blank=True)
    tx = models.CharField(max_length=255, blank=True)
    st = models.CharField(max_length=32, blank=True)

    class Meta:
        db_table = "paypal_pdt"
        verbose_name = "PayPal PDT"

    def _postback(self):
        """
        Perform PayPal PDT Postback validation.
        Sends the transaction ID and business token to PayPal which responses with
        SUCCESS or FAILED.

        """
        return requests.post(self.get_endpoint(),
                             data=dict(cmd="_notify-synch", at=IDENTITY_TOKEN, tx=self.tx)).content

    def get_endpoint(self):
        if getattr(settings, 'PAYPAL_TEST', True):
            return SANDBOX_POSTBACK_ENDPOINT
        else:
            return POSTBACK_ENDPOINT

    def _verify_postback(self):
        # ### Now we don't really care what result was, just whether a flag was set or not.
        from paypal.standard.pdt.forms import PayPalPDTForm

        response_list = self.response.split('\n')
        response_dict = {}
        for i, line in enumerate(response_list):
            unquoted_line = unquote_plus(line).strip()
            if i == 0:
                self.st = unquoted_line
            else:
                if self.st != "SUCCESS":
                    warn_untested()
                    self.set_flag(line)
                    break
                try:
                    if not unquoted_line.startswith(' -'):
                        k, v = unquoted_line.split('=')
                        response_dict[k.strip()] = v.strip()
                except ValueError:
                    pass

        qd = QueryDict('', mutable=True)
        qd.update(response_dict)
        qd.update(dict(ipaddress=self.ipaddress, st=self.st, flag_info=self.flag_info, flag=self.flag,
                       flag_code=self.flag_code))
        pdt_form = PayPalPDTForm(qd, instance=self)
        pdt_form.save(commit=False)

    def __repr__(self):
        return '<PayPalPDT id:{0}>'.format(self.id)

    def __str__(self):
        return "PayPalPDT: {0}".format(self.id)
