# coding=utf-8
"""
The end developer will do most of their work with the PayPalInterface class found
in this module. Configuration, querying, and manipulation can all be done
with it.
"""

import types
import logging
from pprint import pformat
import warnings

import requests

from vendor.paypalapi.settings import PayPalConfig
from vendor.paypalapi.response import PayPalResponse
from vendor.paypalapi.response_list import PayPalResponseList
from vendor.paypalapi.exceptions import (PayPalError,
                               PayPalAPIResponseError,
                               PayPalConfigError)
from vendor.paypalapi.compat import is_py3

if is_py3:
    #noinspection PyUnresolvedReferences
    from urllib.parse import urlencode
else:
    from urllib import urlencode

logger = logging.getLogger('paypal.interface')


class PayPalInterface(object):

    __credentials = ['USER', 'PWD', 'SIGNATURE', 'SUBJECT']

    """
    The end developers will do 95% of their work through this class. API
    queries, configuration, etc, all go through here. See the __init__ method
    for config related details.
    """
    def __init__(self, config=None, **kwargs):
        """
        Constructor, which passes all config directives to the config class
        via kwargs. For example:

            paypal = PayPalInterface(API_USERNAME='somevalue')

        Optionally, you may pass a 'config' kwarg to provide your own
        PayPalConfig object.
        """
        if config:
            # User provided their own PayPalConfig object.
            self.config = config
        else:
            # Take the kwargs and stuff them in a new PayPalConfig object.
            self.config = PayPalConfig(**kwargs)

    def _encode_utf8(self, **kwargs):
        """
        UTF8 encodes all of the NVP values.
        """
        if is_py3:
            # This is only valid for Python 2. In Python 3, unicode is
            # everywhere (yay).
            return kwargs

        unencoded_pairs = kwargs
        for i in unencoded_pairs.keys():
            #noinspection PyUnresolvedReferences
            if isinstance(unencoded_pairs[i], types.UnicodeType):
                unencoded_pairs[i] = unencoded_pairs[i].encode('utf-8')
        return unencoded_pairs

    def _check_required(self, requires, **kwargs):
        """
        Checks kwargs for the values specified in 'requires', which is a tuple
        of strings. These strings are the NVP names of the required values.
        """
        for req in requires:
            # PayPal api is never mixed-case.
            if req.lower() not in kwargs and req.upper() not in kwargs:
                raise PayPalError('missing required : %s' % req)

    def _sanitize_locals(self, data):
        """
        Remove the 'self' key in locals()
        It's more explicit to do it in one function
        """
        if 'self' in data:
            data = data.copy()
            del data['self']

        return data

    def _call(self, method, **kwargs):
        """
        Wrapper method for executing all API commands over HTTP. This method is
        further used to implement wrapper methods listed here:

        https://www.x.com/docs/DOC-1374

        ``method`` must be a supported NVP method listed at the above address.
        ``kwargs`` the actual call parameters
        """
        post_params = self._get_call_params(method, **kwargs)
        payload = post_params['data']
        api_endpoint = post_params['url']

        # This shows all of the key/val pairs we're sending to PayPal.
        if logger.isEnabledFor(logging.DEBUG):
            logger.debug('PayPal NVP Query Key/Vals:\n%s' % pformat(payload))

        http_response = requests.post(**post_params)
        response = PayPalResponse(http_response.text, self.config)
        logger.debug('PayPal NVP API Endpoint: %s' % api_endpoint)

        if not response.success:
            logger.error('A PayPal API error was encountered.')
            safe_payload = dict((p, 'X' * len(v) if p in \
                self.__credentials else v) for (p, v) in payload.items())
            logger.error('PayPal NVP Query Key/Vals (credentials removed):' \
                '\n%s' % pformat(safe_payload))
            logger.error('PayPal NVP Query Response')
            logger.error(response)
            raise PayPalAPIResponseError(response)

        return response

    def _get_call_params(self, method, **kwargs):
        """
        Returns the prepared call parameters. Mind, these will be keyword
        arguments to ``requests.post``.

        ``method`` the NVP method
        ``kwargs`` the actual call parameters
        """
        payload = {'METHOD': method,
                   'VERSION': self.config.API_VERSION}
        certificate = None

        if self.config.API_AUTHENTICATION_MODE == "3TOKEN":
            payload['USER'] = self.config.API_USERNAME
            payload['PWD'] = self.config.API_PASSWORD
            payload['SIGNATURE'] = self.config.API_SIGNATURE
        elif self.config.API_AUTHENTICATION_MODE == "CERTIFICATE":
            payload['USER'] = self.config.API_USERNAME
            payload['PWD'] = self.config.API_PASSWORD
            certificate = (self.config.API_CERTIFICATE_FILENAME,
                           self.config.API_KEY_FILENAME)
        elif self.config.API_AUTHENTICATION_MODE == "UNIPAY":
            payload['SUBJECT'] = self.config.UNIPAY_SUBJECT

        none_configs = [config for config, value in payload.iteritems()\
                        if value is None]
        if none_configs:
            raise PayPalConfigError(
                "Config(s) %s cannot be None. Please, check this "
                "interface's config." % none_configs)

        # all keys in the payload must be uppercase
        for key, value in kwargs.items():
            payload[key.upper()] = value

        return {'data': payload,
                'cert': certificate,
                'url': self.config.API_ENDPOINT,
                'timeout': self.config.HTTP_TIMEOUT,
                'verify': self.config.API_CA_CERTS}

    def address_verify(self, email, street, zip):
        """Shortcut for the AddressVerify method.

        ``email``::
            Email address of a PayPal member to verify.
            Maximum string length: 255 single-byte characters
            Input mask: ?@?.??
        ``street``::
            First line of the billing or shipping postal address to verify.

            To pass verification, the value of Street must match the first three
            single-byte characters of a postal address on file for the PayPal member.

            Maximum string length: 35 single-byte characters.
            Alphanumeric plus - , . ‘ # \
            Whitespace and case of input value are ignored.
        ``zip``::
            Postal code to verify.

            To pass verification, the value of Zip mustmatch the first five
            single-byte characters of the postal code of the verified postal
            address for the verified PayPal member.

            Maximumstring length: 16 single-byte characters.
            Whitespace and case of input value are ignored.
        """
        args = self._sanitize_locals(locals())
        return self._call('AddressVerify', **args)

    def create_recurring_payments_profile(self, **kwargs):
        """Shortcut for the CreateRecurringPaymentsProfile method.
        Currently, this method only supports the Direct Payment flavor.

        It requires standard credit card information and a few additional
        parameters related to the billing. e.g.:

            profile_info = {
                # Credit card information
                'creditcardtype': 'Visa',
                'acct': '4812177017895760',
                'expdate': '102015',
                'cvv2': '123',
                'firstname': 'John',
                'lastname': 'Doe',
                'street': '1313 Mockingbird Lane',
                'city': 'Beverly Hills',
                'state': 'CA',
                'zip': '90110',
                'countrycode': 'US',
                'currencycode': 'USD',
                # Recurring payment information
                'profilestartdate': '2010-10-25T0:0:0',
                'billingperiod': 'Month',
                'billingfrequency': '6',
                'amt': '10.00',
                'desc': '6 months of our product.'
            }
            response = create_recurring_payments_profile(**profile_info)

            The above NVPs compose the bare-minimum request for creating a
            profile. For the complete list of parameters, visit this URI:
            https://www.x.com/docs/DOC-1168
        """
        return self._call('CreateRecurringPaymentsProfile', **kwargs)

    def do_authorization(self, transactionid, amt):
        """Shortcut for the DoAuthorization method.

        Use the TRANSACTIONID from DoExpressCheckoutPayment for the
        ``transactionid``. The latest version of the API does not support the
        creation of an Order from `DoDirectPayment`.

        The `amt` should be the same as passed to `DoExpressCheckoutPayment`.

        Flow for a payment involving a `DoAuthorization` call::

             1. One or many calls to `SetExpressCheckout` with pertinent order
                details, returns `TOKEN`
             1. `DoExpressCheckoutPayment` with `TOKEN`, `PAYMENTACTION` set to
                Order, `AMT` set to the amount of the transaction, returns
                `TRANSACTIONID`
             1. `DoAuthorization` with `TRANSACTIONID` and `AMT` set to the
                amount of the transaction.
             1. `DoCapture` with the `AUTHORIZATIONID` (the `TRANSACTIONID`
                returned by `DoAuthorization`)

        """
        args = self._sanitize_locals(locals())
        return self._call('DoAuthorization', **args)

    def do_capture(self, authorizationid, amt, completetype='Complete', **kwargs):
        """Shortcut for the DoCapture method.

        Use the TRANSACTIONID from DoAuthorization, DoDirectPayment or
        DoExpressCheckoutPayment for the ``authorizationid``.

        The `amt` should be the same as the authorized transaction.
        """
        kwargs.update(self._sanitize_locals(locals()))
        return self._call('DoCapture', **kwargs)

    def do_direct_payment(self, paymentaction="Sale", **kwargs):
        """Shortcut for the DoDirectPayment method.

        ``paymentaction`` could be 'Authorization' or 'Sale'

        To issue a Sale immediately::

            charge = {
                'amt': '10.00',
                'creditcardtype': 'Visa',
                'acct': '4812177017895760',
                'expdate': '012010',
                'cvv2': '962',
                'firstname': 'John',
                'lastname': 'Doe',
                'street': '1 Main St',
                'city': 'San Jose',
                'state': 'CA',
                'zip': '95131',
                'countrycode': 'US',
                'currencycode': 'USD',
            }
            direct_payment("Sale", **charge)

        Or, since "Sale" is the default:

            direct_payment(**charge)

        To issue an Authorization, simply pass "Authorization" instead of "Sale".

        You may also explicitly set ``paymentaction`` as a keyword argument:

            ...
            direct_payment(paymentaction="Sale", **charge)
        """
        kwargs.update(self._sanitize_locals(locals()))
        return self._call('DoDirectPayment', **kwargs)

    def do_void(self, **kwargs):
        """Shortcut for the DoVoid method.

        Use the TRANSACTIONID from DoAuthorization, DoDirectPayment or
        DoExpressCheckoutPayment for the ``AUTHORIZATIONID``.

        Required Kwargs
        ---------------
        * AUTHORIZATIONID
        """
        return self._call('DoVoid', **kwargs)

    def get_express_checkout_details(self, **kwargs):
        """Shortcut for the GetExpressCheckoutDetails method.

        Required Kwargs
        ---------------
        * TOKEN
        """
        return self._call('GetExpressCheckoutDetails', **kwargs)

    def get_transaction_details(self, **kwargs):
        """Shortcut for the GetTransactionDetails method.

        Use the TRANSACTIONID from DoAuthorization, DoDirectPayment or
        DoExpressCheckoutPayment for the ``transactionid``.

        Required Kwargs
        ---------------

        * TRANSACTIONID
        """
        return self._call('GetTransactionDetails', **kwargs)

    def transaction_search(self, **kwargs):
        """Shortcut for the TransactionSearch method.
        Returns a PayPalResponseList object, which merges the L_ syntax list
        to a list of dictionaries with properly named keys.

        Note that the API will limit returned transactions to 100.

        Required Kwargs
        ---------------
        * STARTDATE

        Optional Kwargs
        ---------------
        STATUS = one of ['Pending','Processing','Success','Denied','Reversed']

        """
        plain = self._call('TransactionSearch', **kwargs)
        return PayPalResponseList(plain.raw, self.config)

    def set_express_checkout(self, **kwargs):
        """Start an Express checkout.

        You'll want to use this in conjunction with
        :meth:`generate_express_checkout_redirect_url` to create a payment,
        then figure out where to redirect the user to for them to
        authorize the payment on PayPal's website.

        Required Kwargs
        ---------------

        * PAYMENTREQUEST_0_AMT
        * PAYMENTREQUEST_0_PAYMENTACTION
        * RETURNURL
        * CANCELURL
        """
        return self._call('SetExpressCheckout', **kwargs)

    def refund_transaction(self, transactionid=None, payerid=None, **kwargs):
        """Shortcut for RefundTransaction method.
           Note new API supports passing a PayerID instead of a transaction id, exactly one must be provided.
           Optional:
               INVOICEID
               REFUNDTYPE
               AMT
               CURRENCYCODE
               NOTE
               RETRYUNTIL
               REFUNDSOURCE
               MERCHANTSTOREDETAILS
               REFUNDADVICE
               REFUNDITEMDETAILS
               MSGSUBID

           MERCHANSTOREDETAILS has two fields:
               STOREID
               TERMINALID
           """
        #this line seems like a complete waste of time... kwargs should not be populated
        if (transactionid is None) and (payerid is None):
            raise PayPalError('RefundTransaction requires either a transactionid or a payerid')
        if (transactionid is not None) and (payerid is not None):
            raise PayPalError('RefundTransaction requires only one of transactionid %s and payerid %s' % (transactionid, payerid))
        if transactionid is not None:
            kwargs['TRANSACTIONID'] = transactionid
        else:
            kwargs['PAYERID'] = payerid

        return self._call('RefundTransaction', **kwargs)

    def do_express_checkout_payment(self, **kwargs):
        """Finishes an Express checkout.

        TOKEN is the token that was returned earlier by
        :meth:`set_express_checkout`. This identifies the transaction.

        Required
        --------
        * TOKEN
        * PAYMENTACTION
        * PAYERID
        * AMT

        """
        return self._call('DoExpressCheckoutPayment', **kwargs)

    def generate_express_checkout_redirect_url(self, token, useraction=None):
        """Returns the URL to redirect the user to for the Express checkout.

        Express Checkouts must be verified by the customer by redirecting them
        to the PayPal website. Use the token returned in the response from
        :meth:`set_express_checkout` with this function to figure out where
        to redirect the user to.

        The button text on the PayPal page can be controlled via `useraction`.
        The documented possible values are `commit` and `continue`. However,
        any other value will only result in a warning.

        :param str token: The unique token identifying this transaction.
        :param str useraction: Control the button text on the PayPal page.
        :rtype: str
        :returns: The URL to redirect the user to for approval.
        """
        url_vars = (self.config.PAYPAL_URL_BASE, token)
        url = "%s?cmd=_express-checkout&token=%s" % url_vars
        if useraction:
            if not useraction.lower() in ('commit', 'continue'):
                warnings.warn('useraction=%s is not documented' % useraction,
                              RuntimeWarning)
            url += '&useraction=%s' % useraction
        return url

    def generate_cart_upload_redirect_url(self, **kwargs):
        """https://www.sandbox.paypal.com/webscr
            ?cmd=_cart
            &upload=1
        """
        required_vals = ('business', 'item_name_1', 'amount_1', 'quantity_1')
        self._check_required(required_vals, **kwargs)
        url = "%s?cmd=_cart&upload=1" % self.config.PAYPAL_URL_BASE
        additional = self._encode_utf8(**kwargs)
        additional = urlencode(additional)
        return url + "&" + additional

    def get_recurring_payments_profile_details(self, profileid):
        """Shortcut for the GetRecurringPaymentsProfile method.

        This returns details for a recurring payment plan. The ``profileid`` is
        a value included in the response retrieved by the function
        ``create_recurring_payments_profile``. The profile details include the
        data provided when the profile was created as well as default values
        for ignored fields and some pertinent stastics.

        e.g.:
            response = create_recurring_payments_profile(**profile_info)
            profileid = response.PROFILEID
            details = get_recurring_payments_profile(profileid)

        The response from PayPal is somewhat self-explanatory, but for a
        description of each field, visit the following URI:
        https://www.x.com/docs/DOC-1194
        """
        args = self._sanitize_locals(locals())
        return self._call('GetRecurringPaymentsProfileDetails', **args)

    def manage_recurring_payments_profile_status(self, profileid, action, note=None):
        """Shortcut to the ManageRecurringPaymentsProfileStatus method.

        ``profileid`` is the same profile id used for getting profile details.
        ``action`` should be either 'Cancel', 'Suspend', or 'Reactivate'.
        ``note`` is optional and is visible to the user. It contains the reason for the change in status.
        """
        args = self._sanitize_locals(locals())
        if not note:
            del args['note']
        return self._call('ManageRecurringPaymentsProfileStatus', **args)

    def update_recurring_payments_profile(self, profileid, **kwargs):
        """Shortcut to the UpdateRecurringPaymentsProfile method.

        ``profileid`` is the same profile id used for getting profile details.

        The keyed arguments are data in the payment profile which you wish to
        change. The profileid does not change. Anything else will take the new
        value. Most of, though not all of, the fields available are shared
        with creating a profile, but for the complete list of parameters, you
        can visit the following URI:
        https://www.x.com/docs/DOC-1212
        """
        kwargs.update(self._sanitize_locals(locals()))
        return self._call('UpdateRecurringPaymentsProfile', **kwargs)

    def bm_create_button(self, **kwargs):
        """Shortcut to the BMButtonSearch method.

        See the docs for details on arguments:
        https://cms.paypal.com/mx/cgi-bin/?cmd=_render-content&content_ID=developer/e_howto_api_nvp_BMCreateButton

        The L_BUTTONVARn fields are especially important, so make sure to
        read those and act accordingly. See unit tests for some examples.
        """
        kwargs.update(self._sanitize_locals(locals()))
        return self._call('BMCreateButton', **kwargs)
