#!/usr/bin/env python
# -*- coding: utf-8 -*-
import datetime
import pprint
import time
import urllib
import urllib2

from django.conf import settings
from django.forms.models import fields_for_model
from django.utils.datastructures import MergeDict
from django.utils.http import urlencode

from paypal.pro.models import PayPalNVP, L


TEST = settings.PAYPAL_TEST
USER = settings.PAYPAL_WPP_USER 
PASSWORD = settings.PAYPAL_WPP_PASSWORD
SIGNATURE = settings.PAYPAL_WPP_SIGNATURE
VERSION = 54.0
BASE_PARAMS = dict(USER=USER , PWD=PASSWORD, SIGNATURE=SIGNATURE, VERSION=VERSION)
ENDPOINT = "https://api-3t.paypal.com/nvp"
SANDBOX_ENDPOINT = "https://api-3t.sandbox.paypal.com/nvp"
NVP_FIELDS = fields_for_model(PayPalNVP).keys()


def paypal_time(time_obj=None):
    """Returns a time suitable for PayPal time fields."""
    if time_obj is None:
        time_obj = time.gmtime()
    return time.strftime(PayPalNVP.TIMESTAMP_FORMAT, time_obj)
    
def paypaltime2datetime(s):
    """Convert a PayPal time string to a DateTime."""
    return datetime.datetime(*(time.strptime(s, PayPalNVP.TIMESTAMP_FORMAT)[:6]))


class PayPalError(TypeError):
    """Error thrown when something be wrong."""
    

class PayPalWPP(object):
    """
    Wrapper class for the PayPal Website Payments Pro.
    
    Website Payments Pro Integration Guide:
    https://cms.paypal.com/cms_content/US/en_US/files/developer/PP_WPP_IntegrationGuide.pdf

    Name-Value Pair API Developer Guide and Reference:
    https://cms.paypal.com/cms_content/US/en_US/files/developer/PP_NVPAPI_DeveloperGuide.pdf
    """
    def __init__(self, request, params=BASE_PARAMS):
        """Required - USER / PWD / SIGNATURE / VERSION"""
        self.request = request
        if TEST:
            self.endpoint = SANDBOX_ENDPOINT
        else:
            self.endpoint = ENDPOINT
        self.signature_values = params
        self.signature = urlencode(self.signature_values) + "&"

    def doDirectPayment(self, params):
        """Call PayPal DoDirectPayment method."""
        defaults = {"method": "DoDirectPayment", "paymentaction": "Sale"}
        required = L("creditcardtype acct expdate cvv2 ipaddress firstname lastname street city state countrycode zip amt")
        nvp_obj = self._fetch(params, required, defaults)
        # @@@ Could check cvv2match / avscode are both 'X' or '0'
        # qd = django.http.QueryDict(nvp_obj.response)
        # if qd.get('cvv2match') not in ['X', '0']:
        #   nvp_obj.set_flag("Invalid cvv2match: %s" % qd.get('cvv2match')
        # if qd.get('avscode') not in ['X', '0']:
        #   nvp_obj.set_flag("Invalid avscode: %s" % qd.get('avscode')
        return not nvp_obj.flag

    def setExpressCheckout(self, params):
        """
        Initiates an Express Checkout transaction.
        Optionally, the SetExpressCheckout API operation can set up billing agreements for
        reference transactions and recurring payments.
        Returns a NVP instance - check for token and payerid to continue!
        """
        if self._is_recurring(params):
            params = self._recurring_setExpressCheckout_adapter(params)

        defaults = {"method": "SetExpressCheckout", "noshipping": 1}
        required = L("returnurl cancelurl amt")
        return self._fetch(params, required, defaults)

    def doExpressCheckoutPayment(self, params):
        """
        Check the dude out:
        """
        defaults = {"method": "DoExpressCheckoutPayment", "paymentaction": "Sale"}
        required =L("returnurl cancelurl amt token payerid")
        nvp_obj = self._fetch(params, required, defaults)
        return not nvp_obj.flag
        
    def createRecurringPaymentsProfile(self, params, direct=False):
        """
        Set direct to True to indicate that this is being called as a directPayment.
        Returns True PayPal successfully creates the profile otherwise False.
        """
        defaults = {"method": "CreateRecurringPaymentsProfile"}
        required = L("profilestartdate billingperiod billingfrequency amt")

        # Direct payments require CC data
        if direct:
            required + L("creditcardtype acct expdate firstname lastname")
        else:
            required + L("token payerid")

        nvp_obj = self._fetch(params, required, defaults)
        
        # Flag if profile_type != ActiveProfile
        return not nvp_obj.flag

    def getExpressCheckoutDetails(self, params):
        raise NotImplementedError

    def setCustomerBillingAgreement(self, params):
        raise DeprecationWarning

    def getTransactionDetails(self, params):
        raise NotImplementedError

    def massPay(self, params):
        raise NotImplementedError

    def getRecurringPaymentsProfileDetails(self, params):
        raise NotImplementedError

    def updateRecurringPaymentsProfile(self, params):
        raise NotImplementedError
    
    def billOutstandingAmount(self, params):
        raise NotImplementedError
        
    def manangeRecurringPaymentsProfileStatus(self, params):
        raise NotImplementedError
        
    def refundTransaction(self, params):
        raise NotImplementedError

    def _is_recurring(self, params):
        """Returns True if the item passed is a recurring transaction."""
        return 'billingfrequency' in params

    def _recurring_setExpressCheckout_adapter(self, params):
        """
        The recurring payment interface to SEC is different than the recurring payment
        interface to ECP. This adapts a normal call to look like a SEC call.
        """
        params['l_billingtype0'] = "RecurringPayments"
        params['l_billingagreementdescription0'] = params['desc']

        REMOVE = L("billingfrequency billingperiod profilestartdate desc")
        for k in params.keys():
            if k in REMOVE:
                del params[k]
                
        return params

    def _fetch(self, params, required, defaults):
        """Make the NVP request and store the response."""
        defaults.update(params)
        pp_params = self._check_and_update_params(required, defaults)        
        pp_string = self.signature + urlencode(pp_params)
        response = self._request(pp_string)
        response_params = self._parse_response(response)
        
        if settings.DEBUG:
            print 'PayPal Request:'
            pprint.pprint(defaults)
            print '\nPayPal Response:'
            pprint.pprint(response_params)

        # Gather all NVP parameters to pass to a new instance.
        nvp_params = {}
        for k, v in MergeDict(defaults, response_params).items():
            if k in NVP_FIELDS:
                nvp_params[k] = v    

        # PayPal timestamp has to be formatted.
        if 'timestamp' in nvp_params:
            nvp_params['timestamp'] = paypaltime2datetime(nvp_params['timestamp'])

        nvp_obj = PayPalNVP(**nvp_params)
        nvp_obj.init(self.request, params, response_params)
        nvp_obj.save()
        return nvp_obj
        
    def _request(self, data):
        """Moved out to make testing easier."""
        return urllib2.urlopen(self.endpoint, data).read()

    def _check_and_update_params(self, required, params):
        """
        Ensure all required parameters were passed to the API call and format
        them correctly.
        """
        for r in required:
            if r not in params:
                raise PayPalError("Missing required param: %s" % r)    

        # Upper case all the parameters for PayPal.
        return (dict((k.upper(), v) for k, v in params.iteritems()))

    def _parse_response(self, response):
        """Turn the PayPal response into a dict"""
        response_tokens = {}
        for kv in response.split('&'):
            key, value = kv.split("=")
            response_tokens[key.lower()] = urllib.unquote(value)
        return response_tokens