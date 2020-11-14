#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import unicode_literals

import datetime
import logging
import pprint
import time

import requests
from django.conf import settings
from django.forms.models import fields_for_model
from django.http import QueryDict
from django.utils import timezone
from django.utils.functional import cached_property
from django.utils.http import urlencode

from paypal.pro.exceptions import PayPalFailure
from paypal.pro.models import PayPalNVP
from paypal.pro.signals import (
    payment_profile_created, payment_was_successful, recurring_cancel, recurring_reactivate, recurring_suspend
)
from paypal.utils import warn_untested

USER = settings.PAYPAL_WPP_USER
PASSWORD = settings.PAYPAL_WPP_PASSWORD
SIGNATURE = settings.PAYPAL_WPP_SIGNATURE
VERSION = 116.0
BASE_PARAMS = dict(USER=USER, PWD=PASSWORD, SIGNATURE=SIGNATURE, VERSION=VERSION)
ENDPOINT = "https://api-3t.paypal.com/nvp"
SANDBOX_ENDPOINT = "https://api-3t.sandbox.paypal.com/nvp"

EXPRESS_ENDPOINT = "https://www.paypal.com/webscr?cmd=_express-checkout&%s"
SANDBOX_EXPRESS_ENDPOINT = "https://www.sandbox.paypal.com/webscr?cmd=_express-checkout&%s"


log = logging.getLogger('paypal.pro')


def paypal_time(time_obj=None):
    """Returns a time suitable for PayPal time fields."""
    warn_untested()
    if time_obj is None:
        time_obj = time.gmtime()
    return time.strftime(PayPalNVP.TIMESTAMP_FORMAT, time_obj)


def paypaltime2datetime(s):
    """Convert a PayPal time string to a DateTime."""
    naive = datetime.datetime.strptime(s, PayPalNVP.TIMESTAMP_FORMAT)
    if not settings.USE_TZ:
        return naive
    else:
        # TIMESTAMP_FORMAT is UTC
        return timezone.make_aware(naive, timezone.utc)


class PayPalError(TypeError):
    """Error thrown when something is wrong."""


def express_endpoint():
    if getattr(settings, 'PAYPAL_TEST', True):
        return SANDBOX_EXPRESS_ENDPOINT
    else:
        return EXPRESS_ENDPOINT


def express_endpoint_for_token(token, commit=False):
    """
    Returns the PayPal Express Checkout endpoint for a token.
    Pass 'commit=True' if you will not prompt for confirmation when the user
    returns to your site.
    """
    pp_params = dict(token=token)
    if commit:
        pp_params['useraction'] = 'commit'
    return express_endpoint() % urlencode(pp_params)


def strip_ip_port(ip_address):
    """
    Strips the port from an IPv4 or IPv6 address, returns a unicode object.
    """

    # IPv4 with or without port
    if '.' in ip_address:
        cleaned_ip = ip_address.split(':')[0]

    # IPv6 with port
    elif ']:' in ip_address:
        # Remove the port following last ':', and then strip first and last chars for [].
        cleaned_ip = ip_address.rpartition(':')[0][1:-1]

    # IPv6 without port
    else:
        cleaned_ip = ip_address

    return cleaned_ip


class PayPalWPP(object):
    """
    Wrapper class for the PayPal Website Payments Pro.

    Website Payments Pro Integration Guide:
    https://cms.paypal.com/cms_content/US/en_US/files/developer/PP_WPP_IntegrationGuide.pdf

    Name-Value Pair API Developer Guide and Reference:
    https://cms.paypal.com/cms_content/US/en_US/files/developer/PP_NVPAPI_DeveloperGuide.pdf
    """

    def __init__(self, request=None, params=BASE_PARAMS):
        """Required - USER / PWD / SIGNATURE / VERSION"""
        self.request = request
        if getattr(settings, 'PAYPAL_TEST', True):
            self.endpoint = SANDBOX_ENDPOINT
        else:
            self.endpoint = ENDPOINT
        self.signature_values = params
        self.signature = urlencode(self.signature_values) + "&"

    @cached_property
    def NVP_FIELDS(self):
        # Put this onto class and load lazily, because in some cases there is an
        # import order problem if we put it at module level.
        return list(fields_for_model(PayPalNVP).keys())

    def doDirectPayment(self, params):
        """Call PayPal DoDirectPayment method."""
        defaults = {"method": "DoDirectPayment", "paymentaction": "Sale"}
        required = ["creditcardtype",
                    "acct",
                    "expdate",
                    "cvv2",
                    "ipaddress",
                    "firstname",
                    "lastname",
                    "street",
                    "city",
                    "state",
                    "countrycode",
                    "zip",
                    "amt",
                    ]
        nvp_obj = self._fetch(params, required, defaults)
        if nvp_obj.flag:
            raise PayPalFailure(nvp_obj.flag_info, nvp=nvp_obj)
        payment_was_successful.send(sender=nvp_obj, **params)
        # @@@ Could check cvv2match / avscode are both 'X' or '0'
        # qd = django.http.QueryDict(nvp_obj.response)
        # if qd.get('cvv2match') not in ['X', '0']:
        #   nvp_obj.set_flag("Invalid cvv2match: %s" % qd.get('cvv2match')
        # if qd.get('avscode') not in ['X', '0']:
        #   nvp_obj.set_flag("Invalid avscode: %s" % qd.get('avscode')
        return nvp_obj

    def setExpressCheckout(self, params):
        """
        Initiates an Express Checkout transaction.
        Optionally, the SetExpressCheckout API operation can set up billing agreements for
        reference transactions and recurring payments.
        Returns a NVP instance - check for token and payerid to continue!
        """
        if "amt" in params:
            import warnings

            warnings.warn("'amt' has been deprecated. 'paymentrequest_0_amt' "
                          "should be used instead.", DeprecationWarning)
            # Make a copy so we don't change things unexpectedly
            params = params.copy()
            params.update({'paymentrequest_0_amt': params['amt']})
            del params['amt']
        if self._is_recurring(params):
            params = self._recurring_setExpressCheckout_adapter(params)

        defaults = {"method": "SetExpressCheckout", "noshipping": 1}
        required = ["returnurl", "cancelurl", "paymentrequest_0_amt"]
        nvp_obj = self._fetch(params, required, defaults)
        if nvp_obj.flag:
            raise PayPalFailure(nvp_obj.flag_info, nvp=nvp_obj)
        return nvp_obj

    def doExpressCheckoutPayment(self, params):
        """
        Check the dude out:
        """
        if "amt" in params:
            import warnings

            warnings.warn("'amt' has been deprecated. 'paymentrequest_0_amt' "
                          "should be used instead.", DeprecationWarning)
            # Make a copy so we don't change things unexpectedly
            params = params.copy()
            params.update({'paymentrequest_0_amt': params['amt']})
            del params['amt']
        defaults = {"method": "DoExpressCheckoutPayment", "paymentaction": "Sale"}
        required = ["paymentrequest_0_amt", "token", "payerid"]
        nvp_obj = self._fetch(params, required, defaults)
        if nvp_obj.flag:
            raise PayPalFailure(nvp_obj.flag_info, nvp=nvp_obj)
        payment_was_successful.send(sender=nvp_obj, **params)
        return nvp_obj

    def createRecurringPaymentsProfile(self, params, direct=False):
        """
        Set direct to True to indicate that this is being called as a directPayment.
        Returns True PayPal successfully creates the profile otherwise False.
        """
        defaults = {"method": "CreateRecurringPaymentsProfile"}
        required = ["profilestartdate", "billingperiod", "billingfrequency", "amt"]

        # Direct payments require CC data
        if direct:
            required + ["creditcardtype", "acct", "expdate", "firstname", "lastname"]
        else:
            required + ["token", "payerid"]

        nvp_obj = self._fetch(params, required, defaults)

        # Flag if profile_type != ActiveProfile
        if nvp_obj.flag:
            raise PayPalFailure(nvp_obj.flag_info, nvp=nvp_obj)
        payment_profile_created.send(sender=nvp_obj, **params)
        return nvp_obj

    def getExpressCheckoutDetails(self, params):
        defaults = {"method": "GetExpressCheckoutDetails"}
        required = ["token"]
        nvp_obj = self._fetch(params, required, defaults)
        if nvp_obj.flag:
            raise PayPalFailure(nvp_obj.flag_info, nvp=nvp_obj)
        return nvp_obj

    def setCustomerBillingAgreement(self, params):
        raise DeprecationWarning

    def createBillingAgreement(self, params):
        """
        Create a billing agreement for future use, without any initial payment
        """
        defaults = {"method": "CreateBillingAgreement"}
        required = ["token"]
        nvp_obj = self._fetch(params, required, defaults)
        if nvp_obj.flag:
            raise PayPalFailure(nvp_obj.flag_info, nvp=nvp_obj)
        return nvp_obj

    def getTransactionDetails(self, params):
        defaults = {"method": "GetTransactionDetails"}
        required = ["transactionid"]

        nvp_obj = self._fetch(params, required, defaults)
        if nvp_obj.flag:
            raise PayPalFailure(nvp_obj.flag_info, nvp=nvp_obj)
        return nvp_obj

    def massPay(self, params):
        raise NotImplementedError

    def getRecurringPaymentsProfileDetails(self, params):
        raise NotImplementedError

    def updateRecurringPaymentsProfile(self, params):
        defaults = {"method": "UpdateRecurringPaymentsProfile"}
        required = ["profileid"]

        nvp_obj = self._fetch(params, required, defaults)
        if nvp_obj.flag:
            raise PayPalFailure(nvp_obj.flag_info, nvp=nvp_obj)
        return nvp_obj

    def billOutstandingAmount(self, params):
        raise NotImplementedError

    def manangeRecurringPaymentsProfileStatus(self, params, fail_silently=False):
        """
        Requires `profileid` and `action` params.
        Action must be either "Cancel", "Suspend", or "Reactivate".
        """
        defaults = {"method": "ManageRecurringPaymentsProfileStatus"}
        required = ["profileid", "action"]

        nvp_obj = self._fetch(params, required, defaults)

        # TODO: This fail silently check should be using the error code, but its not easy to access
        flag_info_test_string = 'Invalid profile status for cancel action; profile should be active or suspended'
        if not nvp_obj.flag or (fail_silently and nvp_obj.flag_info == flag_info_test_string):
            if params['action'] == 'Cancel':
                recurring_cancel.send(sender=nvp_obj)
            elif params['action'] == 'Suspend':
                recurring_suspend.send(sender=nvp_obj)
            elif params['action'] == 'Reactivate':
                recurring_reactivate.send(sender=nvp_obj)
        else:
            raise PayPalFailure(nvp_obj.flag_info, nvp=nvp_obj)
        return nvp_obj

    def refundTransaction(self, params):
        raise NotImplementedError

    def doReferenceTransaction(self, params):
        """
        Process a payment from a buyer's account, identified by a previous
        transaction.
        The `paymentaction` param defaults to "Sale", but may also contain the
        values "Authorization" or "Order".
        """
        defaults = {"method": "DoReferenceTransaction",
                    "paymentaction": "Sale"}
        required = ["referenceid", "amt"]

        nvp_obj = self._fetch(params, required, defaults)
        if nvp_obj.flag:
            raise PayPalFailure(nvp_obj.flag_info, nvp=nvp_obj)
        return nvp_obj

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

        REMOVE = ["billingfrequency", "billingperiod", "profilestartdate", "desc"]
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

        log.debug('PayPal Request:\n%s\n', pprint.pformat(defaults))
        log.debug('PayPal Response:\n%s\n', pprint.pformat(response_params))

        # Gather all NVP parameters to pass to a new instance.
        nvp_params = {}
        tmpd = defaults.copy()
        tmpd.update(response_params)
        for k, v in tmpd.items():
            if k in self.NVP_FIELDS:
                nvp_params[str(k)] = v

        # PayPal timestamp has to be formatted.
        if 'timestamp' in nvp_params:
            nvp_params['timestamp'] = paypaltime2datetime(nvp_params['timestamp'])

        nvp_obj = PayPalNVP(**nvp_params)
        nvp_obj.init(self.request, params, response_params)
        nvp_obj.save()
        return nvp_obj

    def _request(self, data):
        """Moved out to make testing easier."""
        return requests.post(self.endpoint, data=data.encode("ascii")).content

    def _check_and_update_params(self, required, params):
        """
        Ensure all required parameters were passed to the API call and format
        them correctly.
        """
        for r in required:
            if r not in params:
                raise PayPalError("Missing required param: %s" % r)

        # Upper case all the parameters for PayPal.
        return (dict((k.upper(), v) for k, v in params.items()))

    def _parse_response(self, response):
        """Turn the PayPal response into a dict"""
        q = QueryDict(response, encoding='UTF-8').dict()
        return {k.lower(): v for k, v in q.items()}
