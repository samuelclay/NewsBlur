#!/usr/bin/env python
# -*- coding: utf-8 -*-
from urllib import unquote_plus
import urllib2
from django.db import models
from django.conf import settings
from django.http import QueryDict
from django.utils.http import urlencode
from paypal.standard.models import PayPalStandardBase
from paypal.standard.conf import POSTBACK_ENDPOINT, SANDBOX_POSTBACK_ENDPOINT
from paypal.standard.pdt.signals import pdt_successful, pdt_failed

# ### Todo: Move this logic to conf.py:
# if paypal.standard.pdt is in installed apps
# ... then check for this setting in conf.py
class PayPalSettingsError(Exception):
    """Raised when settings are incorrect."""

try:
    IDENTITY_TOKEN = settings.PAYPAL_IDENTITY_TOKEN
except:
    raise PayPalSettingsError("You must set PAYPAL_IDENTITY_TOKEN in settings.py. Get this token by enabling PDT in your PayPal account.")


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
        postback_dict = dict(cmd="_notify-synch", at=IDENTITY_TOKEN, tx=self.tx)
        postback_params = urlencode(postback_dict)
        return urllib2.urlopen(self.get_endpoint(), postback_params).read()
    
    def get_endpoint(self):
        """Use the sandbox when in DEBUG mode as we don't have a test_ipn variable in pdt."""
        if settings.DEBUG:
            return SANDBOX_POSTBACK_ENDPOINT
        else:
            return POSTBACK_ENDPOINT
    
    def _verify_postback(self):
        # ### Now we don't really care what result was, just whether a flag was set or not.
        from paypal.standard.pdt.forms import PayPalPDTForm
        result = False
        response_list = self.response.split('\n')
        response_dict = {}
        for i, line in enumerate(response_list):
            unquoted_line = unquote_plus(line).strip()        
            if i == 0:
                self.st = unquoted_line
                if self.st == "SUCCESS":
                    result = True
            else:
                if self.st != "SUCCESS":
                    self.set_flag(line)
                    break
                try:                        
                    if not unquoted_line.startswith(' -'):
                        k, v = unquoted_line.split('=')                        
                        response_dict[k.strip()] = v.strip()
                except ValueError, e:
                    pass

        qd = QueryDict('', mutable=True)
        qd.update(response_dict)
        qd.update(dict(ipaddress=self.ipaddress, st=self.st, flag_info=self.flag_info))
        pdt_form = PayPalPDTForm(qd, instance=self)
        pdt_form.save(commit=False)
        
    def send_signals(self):
        # Send the PDT signals...
        if self.flag:
            pdt_failed.send(sender=self)
        else:
            pdt_successful.send(sender=self)