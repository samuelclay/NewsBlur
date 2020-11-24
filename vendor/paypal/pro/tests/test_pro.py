#!/usr/bin/python
# -*- coding: utf-8 -*-
from __future__ import unicode_literals

import warnings
from decimal import Decimal

import mock
from django.forms import ValidationError
from django.test import TestCase
from django.test.client import RequestFactory
from django.test.utils import override_settings
from vcr import VCR

from paypal.pro.exceptions import PayPalFailure
from paypal.pro.fields import CreditCardField
from paypal.pro.helpers import VERSION, PayPalError, PayPalWPP, strip_ip_port
from paypal.pro.signals import payment_was_successful
from paypal.pro.views import PayPalPro

from .settings import TEMPLATE_DIRS, TEMPLATES

RF = RequestFactory()
REQUEST = RF.get("/pay/", REMOTE_ADDR="127.0.0.1:8000")


vcr = VCR(path_transformer=VCR.ensure_suffix('.yaml'))


class DummyPayPalWPP(PayPalWPP):
    pass

#     """Dummy class for testing PayPalWPP."""
#     responses = {
#         # @@@ Need some reals data here.
#         "DoDirectPayment": """ack=Success&timestamp=2009-03-12T23%3A52%3A33Z&l_severitycode0=Error&l_shortmessage0=Security+error&l_longmessage0=Security+header+is+not+valid&version=54.0&build=854529&l_errorcode0=&correlationid=""",  # noqa
#     }
#
#     def _request(self, data):
#         return self.responses["DoDirectPayment"]


class CreditCardFieldTest(TestCase):
    def test_CreditCardField(self):
        field = CreditCardField()
        field.clean('4797503429879309')
        self.assertEqual(field.card_type, "Visa")
        self.assertRaises(ValidationError, CreditCardField().clean, '1234567890123455')

    def test_invalidCreditCards(self):
        self.assertEqual(CreditCardField().clean('4797-5034-2987-9309'), '4797503429879309')


def ppp_wrapper(request, handler=None):
    item = {"paymentrequest_0_amt": "10.00",
            "inv": "inventory",
            "custom": "tracking",
            "cancelurl": "http://foo.com/cancel",
            "returnurl": "http://foo.com/return"}

    if handler is None:
        handler = lambda nvp: nvp  # NOP
    ppp = PayPalPro(
        item=item,                             # what you're selling
        payment_template="payment.html",       # template name for payment
        confirm_template="confirmation.html",  # template name for confirmation
        success_url="/success/",               # redirect location after success
        nvp_handler=handler
        )

    return ppp(request)


@override_settings(TEMPLATE_DIRS=TEMPLATE_DIRS,
                   TEMPLATES=TEMPLATES)
class PayPalProTest(TestCase):

    @vcr.use_cassette()
    def test_get(self):
        response = ppp_wrapper(RF.get('/'))
        self.assertContains(response, 'Show me the money')
        self.assertEqual(response.status_code, 200)

    @vcr.use_cassette()
    def test_get_redirect(self):
        response = ppp_wrapper(RF.get('/', {'express': '1'}))
        self.assertEqual(response.status_code, 302)

    @vcr.use_cassette()
    def test_validate_confirm_form_error(self):
        response = ppp_wrapper(RF.post('/',
                                       {'token': '123',
                                        'PayerID': '456'}))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.context_data.get('errors', ''),
                         PayPalPro.errors['processing'])

    @vcr.use_cassette()
    @mock.patch.object(PayPalWPP, 'doExpressCheckoutPayment', autospec=True)
    def test_validate_confirm_form_ok(self, doExpressCheckoutPayment):
        nvp = {'mock': True}
        doExpressCheckoutPayment.return_value = nvp

        received = []

        def handler(nvp):
            received.append(nvp)

        response = ppp_wrapper(RF.post('/',
                                       {'token': '123',
                                        'PayerID': '456'}),
                               handler=handler)
        self.assertEqual(response.status_code, 302)
        self.assertEqual(response['Location'], '/success/')
        self.assertEqual(len(received), 1)


class PayPalWPPTest(TestCase):
    def setUp(self):

        self.item = {
            'amt': '9.95',
            'inv': 'inv',
            'custom': 'custom',
            'next': 'http://www.example.com/next/',
            'returnurl': 'http://www.example.com/pay/',
            'cancelurl': 'http://www.example.com/cancel/'
        }
        # Handle different parameters for Express Checkout
        self.ec_item = {
            'paymentrequest_0_amt': '9.95',
            'inv': 'inv',
            'custom': 'custom',
            'next': 'http://www.example.com/next/',
            'returnurl': 'http://www.example.com/pay/',
            'cancelurl': 'http://www.example.com/cancel/'
        }
        self.wpp = DummyPayPalWPP(REQUEST)

    @vcr.use_cassette()
    def test_doDirectPayment_missing_params(self):
        data = {'firstname': 'Chewbacca'}
        self.assertRaises(PayPalError, self.wpp.doDirectPayment, data)

    @vcr.use_cassette()
    def test_doDirectPayment_valid(self):
        data = {
            'firstname': 'Brave',
            'lastname': 'Star',
            'street': '1 Main St',
            'city': u'San Jos\xe9',
            'state': 'CA',
            'countrycode': 'US',
            'zip': '95131',
            'acct': '4032039938039650',
            'expdate': '112021',
            'cvv2': '',
            'creditcardtype': 'visa',
            'ipaddress': '10.0.1.199', }
        data.update(self.item)
        self.assertTrue(self.wpp.doDirectPayment(data))

    @vcr.use_cassette()
    def test_doDirectPayment_invalid(self):
        data = {
            'firstname': 'Epic',
            'lastname': 'Fail',
            'street': '100 Georgia St',
            'city': 'Vancouver',
            'state': 'BC',
            'countrycode': 'CA',
            'zip': 'V6V 1V1',
            'expdate': '012019',
            'cvv2': '999',
            'acct': '1234567890',
            'creditcardtype': 'visa',
            'ipaddress': '10.0.1.199', }
        data.update(self.item)
        self.assertRaises(PayPalFailure, self.wpp.doDirectPayment, data)

    @vcr.use_cassette()
    def test_doDirectPayment_valid_with_signal(self):
        data = {
            'firstname': 'Brave',
            'lastname': 'Star',
            'street': '1 Main St',
            'city': u'San Jos\xe9',
            'state': 'CA',
            'countrycode': 'US',
            'zip': '95131',
            'acct': '4032039938039650',
            'expdate': '112021',
            'cvv2': '',
            'creditcardtype': 'visa',
            'ipaddress': '10.0.1.199', }
        data.update(self.item)

        self.got_signal = False
        self.signal_obj = None

        def handle_signal(sender, **kwargs):
            self.got_signal = True
            self.signal_obj = sender

        payment_was_successful.connect(handle_signal)
        self.assertTrue(self.wpp.doDirectPayment(data))
        self.assertTrue(self.got_signal)

    @vcr.use_cassette()
    def test_setExpressCheckout(self):
        nvp_obj = self.wpp.setExpressCheckout(self.ec_item)
        self.assertEqual(nvp_obj.ack, "Success")

    @vcr.use_cassette()
    @mock.patch.object(PayPalWPP, '_request', autospec=True)
    def test_setExpressCheckout_deprecation(self, mock_request_object):
        mock_request_object.return_value = 'ack=Success&token=EC-XXXX&version=%s'
        item = self.ec_item.copy()
        item.update({'amt': item['paymentrequest_0_amt']})
        del item['paymentrequest_0_amt']
        with warnings.catch_warnings(record=True) as warning_list:
            warnings.simplefilter("always")
            nvp_obj = self.wpp.setExpressCheckout(item)
            # Make sure our warning was given
            self.assertTrue(any(warned.category == DeprecationWarning
                                for warned in warning_list))
            # Make sure the method still went through
            call_args = mock_request_object.call_args
            self.assertIn('PAYMENTREQUEST_0_AMT=%s' % item['amt'],
                          call_args[0][1])
            self.assertEqual(nvp_obj.ack, "Success")

    @vcr.use_cassette()
    @mock.patch.object(PayPalWPP, '_request', autospec=True)
    def test_doExpressCheckoutPayment(self, mock_request_object):
        ec_token = 'EC-1234567890'
        payerid = 'LXYZABC1234'
        item = self.ec_item.copy()
        item.update({'token': ec_token, 'payerid': payerid})
        mock_request_object.return_value = 'ack=Success&token=%s&version=%spaymentinfo_0_amt=%s' % \
            (ec_token, VERSION, self.ec_item['paymentrequest_0_amt'])
        wpp = PayPalWPP(REQUEST)
        wpp.doExpressCheckoutPayment(item)
        call_args = mock_request_object.call_args
        self.assertIn('VERSION=%s' % VERSION, call_args[0][1])
        self.assertIn('METHOD=DoExpressCheckoutPayment', call_args[0][1])
        self.assertIn('TOKEN=%s' % ec_token, call_args[0][1])
        self.assertIn('PAYMENTREQUEST_0_AMT=%s' % item['paymentrequest_0_amt'],
                      call_args[0][1])
        self.assertIn('PAYERID=%s' % payerid, call_args[0][1])

    @vcr.use_cassette()
    @mock.patch.object(PayPalWPP, '_request', autospec=True)
    def test_doExpressCheckoutPayment_invalid(self, mock_request_object):
        ec_token = 'EC-1234567890'
        payerid = 'LXYZABC1234'
        item = self.ec_item.copy()
        item.update({'token': ec_token, 'payerid': payerid})
        mock_request_object.return_value = 'ack=Failure&l_errorcode=42&l_longmessage0=Broken'
        wpp = PayPalWPP(REQUEST)
        with self.assertRaises(PayPalFailure):
            wpp.doExpressCheckoutPayment(item)

    @vcr.use_cassette()
    @mock.patch.object(PayPalWPP, '_request', autospec=True)
    def test_doExpressCheckoutPayment_deprecation(self, mock_request_object):
        mock_request_object.return_value = 'ack=Success&token=EC-XXXX&version=%s'
        ec_token = 'EC-1234567890'
        payerid = 'LXYZABC1234'
        item = self.ec_item.copy()
        item.update({'amt': item['paymentrequest_0_amt'],
                     'token': ec_token,
                     'payerid': payerid})
        del item['paymentrequest_0_amt']
        with warnings.catch_warnings(record=True) as warning_list:
            warnings.simplefilter("always")
            nvp_obj = self.wpp.doExpressCheckoutPayment(item)
            # Make sure our warning was given
            self.assertTrue(any(warned.category == DeprecationWarning
                                for warned in warning_list))
            # Make sure the method still went through
            call_args = mock_request_object.call_args
            self.assertIn('PAYMENTREQUEST_0_AMT=%s' % item['amt'],
                          call_args[0][1])
            self.assertEqual(nvp_obj.ack, "Success")

    @vcr.use_cassette()
    @mock.patch.object(PayPalWPP, '_request', autospec=True)
    def test_createBillingAgreement(self, mock_request_object):
        mock_request_object.return_value = 'ack=Success&billingagreementid=B-XXXXX&version=%s' % VERSION
        wpp = PayPalWPP(REQUEST)
        nvp = wpp.createBillingAgreement({'token': 'dummy token'})
        call_args = mock_request_object.call_args
        self.assertIn('VERSION=%s' % VERSION, call_args[0][1])
        self.assertIn('METHOD=CreateBillingAgreement', call_args[0][1])
        self.assertIn('TOKEN=dummy+token', call_args[0][1])
        self.assertEqual(nvp.method, 'CreateBillingAgreement')
        self.assertEqual(nvp.ack, 'Success')
        mock_request_object.return_value = 'ack=Failure&l_errorcode=42&l_longmessage0=Broken'
        with self.assertRaises(PayPalFailure):
            nvp = wpp.createBillingAgreement({'token': 'dummy token'})

    @vcr.use_cassette()
    @mock.patch.object(PayPalWPP, '_request', autospec=True)
    def test_doReferenceTransaction_valid(self, mock_request_object):
        reference_id = 'B-1234'
        amount = Decimal('10.50')
        mock_request_object.return_value = (
            'ack=Success&paymentstatus=Completed&amt=%s&version=%s&billingagreementid=%s' %
            (amount, VERSION, reference_id))
        wpp = PayPalWPP(REQUEST)
        nvp = wpp.doReferenceTransaction({'referenceid': reference_id,
                                          'amt': amount})
        call_args = mock_request_object.call_args
        self.assertIn('VERSION=%s' % VERSION, call_args[0][1])
        self.assertIn('METHOD=DoReferenceTransaction', call_args[0][1])
        self.assertIn('REFERENCEID=%s' % reference_id, call_args[0][1])
        self.assertIn('AMT=%s' % amount, call_args[0][1])
        self.assertEqual(nvp.method, 'DoReferenceTransaction')
        self.assertEqual(nvp.ack, 'Success')

    @vcr.use_cassette()
    @mock.patch.object(PayPalWPP, '_request', autospec=True)
    def test_doReferenceTransaction_invalid(self, mock_request_object):
        reference_id = 'B-1234'
        amount = Decimal('10.50')
        mock_request_object.return_value = 'ack=Failure&l_errorcode=42&l_longmessage0=Broken'
        wpp = PayPalWPP(REQUEST)
        with self.assertRaises(PayPalFailure):
            wpp.doReferenceTransaction({'referenceid': reference_id,
                                        'amt': amount})

    def test_strip_ip_port(self):
        IPv4 = '192.168.0.1'
        IPv6 = '2001:0db8:85a3:0000:0000:8a2e:0370:7334'
        PORT = '8000'

        # IPv4 with port
        test = '%s:%s' % (IPv4, PORT)
        self.assertEqual(IPv4, strip_ip_port(test))

        # IPv4 without port
        test = IPv4
        self.assertEqual(IPv4, strip_ip_port(test))

        # IPv6 with port
        test = '[%s]:%s' % (IPv6, PORT)
        self.assertEqual(IPv6, strip_ip_port(test))

        # IPv6 without port
        test = IPv6
        self.assertEqual(IPv6, strip_ip_port(test))

        # No IP
        self.assertEqual('', strip_ip_port(''))

# -- DoExpressCheckoutPayment
# PayPal Request:
# {'amt': '10.00',
#  'cancelurl': u'http://xxx.xxx.xxx.xxx/deploy/480/upgrade/?upgrade=cname',
#  'custom': u'website_id=480&cname=1',
#  'inv': u'website-480-cname',
#  'method': 'DoExpressCheckoutPayment',
#  'next': u'http://xxx.xxx.xxx.xxx/deploy/480/upgrade/?upgrade=cname',
#  'payerid': u'BN5JZ2V7MLEV4',
#  'paymentaction': 'Sale',
#  'returnurl': u'http://xxx.xxx.xxx.xxx/deploy/480/upgrade/?upgrade=cname',
#  'token': u'EC-6HW17184NE0084127'}
#
# PayPal Response:
# {'ack': 'Success',
#  'amt': '10.00',
#  'build': '848077',
#  'correlationid': '375f4773c3d34',
#  'currencycode': 'USD',
#  'feeamt': '0.59',
#  'ordertime': '2009-03-04T20:56:08Z',
#  'paymentstatus': 'Completed',
#  'paymenttype': 'instant',
#  'pendingreason': 'None',
#  'reasoncode': 'None',
#  'taxamt': '0.00',
#  'timestamp': '2009-03-04T20:56:09Z',
#  'token': 'EC-6HW17184NE0084127',
#  'transactionid': '3TG42202A7335864V',
#  'transactiontype': 'expresscheckout',
#  'version': '54.0'}
