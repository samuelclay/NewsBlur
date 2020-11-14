"""
run this with ./manage.py test website
see http://www.djangoproject.com/documentation/testing/ for details
"""
from __future__ import unicode_literals

import mock
from django.conf import settings
from django.template.loader import render_to_string
from django.test import TestCase
from django.test.utils import override_settings

from paypal.standard.conf import POSTBACK_ENDPOINT, SANDBOX_POSTBACK_ENDPOINT
from paypal.standard.pdt.models import PayPalPDT

from .settings import TEMPLATE_DIRS, TEMPLATES


class DummyPayPalPDT(object):
    def __init__(self, update_context_dict={}):
        self.context_dict = {'st': 'SUCCESS', 'custom': 'cb736658-3aad-4694-956f-d0aeade80194',
                             'txn_id': '1ED550410S3402306', 'mc_gross': '225.00',
                             'business': 'test@example.com', 'error': 'Error code: 1234'}

        self.context_dict.update(update_context_dict)
        self.response = ''

    def update_with_get_params(self, get_params):
        if 'tx' in get_params:
            self.context_dict['txn_id'] = get_params.get('tx')
        if 'amt' in get_params:
            self.context_dict['mc_gross'] = get_params.get('amt')
        if 'cm' in get_params:
            self.context_dict['custom'] = get_params.get('cm')

    def _postback(self, test=True):
        """Perform a Fake PayPal PDT Postback request."""
        return render_to_string("pdt/test_pdt_response.html", self.context_dict).encode('utf-8')


@override_settings(ROOT_URLCONF="paypal.standard.pdt.tests.test_urls",
                   TEMPLATES=TEMPLATES,
                   TEMPLATE_DIRS=TEMPLATE_DIRS)
class PDTTest(TestCase):

    def setUp(self):
        # set up some dummy PDT get parameters
        self.get_params = {"tx": "4WJ86550014687441", "st": "Completed", "amt": "225.00", "cc": "EUR",
                           "cm": "a3e192b8-8fea-4a86-b2e8-d5bf502e36be", "item_number": "",
                           "sig": "blahblahblah"}

        # monkey patch the PayPalPDT._postback function
        self.dpppdt = DummyPayPalPDT()
        self.dpppdt.update_with_get_params(self.get_params)
        PayPalPDT._postback = self.dpppdt._postback

    def test_verify_postback(self):
        dpppdt = DummyPayPalPDT()
        paypal_response = dpppdt._postback().decode('ascii')
        assert ('SUCCESS' in paypal_response)
        self.assertEqual(len(PayPalPDT.objects.all()), 0)
        pdt_obj = PayPalPDT()
        pdt_obj.ipaddress = '127.0.0.1'
        pdt_obj.response = paypal_response
        pdt_obj._verify_postback()
        self.assertEqual(len(PayPalPDT.objects.all()), 0)
        self.assertEqual(pdt_obj.txn_id, '1ED550410S3402306')
        # Issue #121: Ensure for doesn't blank non-PayPal-supplied fields
        self.assertEqual(pdt_obj.ipaddress, '127.0.0.1')
        self.assertEqual(pdt_obj.response, paypal_response)

    def test_pdt(self):
        self.assertEqual(len(PayPalPDT.objects.all()), 0)
        self.dpppdt.update_with_get_params(self.get_params)
        paypal_response = self.client.get("/pdt/", self.get_params)
        self.assertContains(paypal_response, 'Transaction complete', status_code=200)
        self.assertEqual(len(PayPalPDT.objects.all()), 1)

    def test_double_pdt_get(self):
        self.assertEqual(len(PayPalPDT.objects.all()), 0)
        paypal_response = self.client.get("/pdt/", self.get_params)
        self.assertContains(paypal_response, 'Transaction complete', status_code=200)
        self.assertEqual(len(PayPalPDT.objects.all()), 1)
        pdt_obj = PayPalPDT.objects.all()[0]
        self.assertEqual(pdt_obj.flag, False)
        paypal_response = self.client.get("/pdt/", self.get_params)
        self.assertContains(paypal_response, 'Transaction complete', status_code=200)
        self.assertEqual(len(PayPalPDT.objects.all()), 1)  # we don't create a new pdt
        pdt_obj = PayPalPDT.objects.all()[0]
        self.assertEqual(pdt_obj.flag, False)

    def test_no_txn_id_in_pdt(self):
        self.dpppdt.context_dict.pop('txn_id')
        self.get_params = {}
        paypal_response = self.client.get("/pdt/", self.get_params)
        self.assertContains(paypal_response, 'Transaction Failed', status_code=200)
        self.assertEqual(len(PayPalPDT.objects.all()), 0)

    def test_custom_passthrough(self):
        self.assertEqual(len(PayPalPDT.objects.all()), 0)
        self.dpppdt.update_with_get_params(self.get_params)
        paypal_response = self.client.get("/pdt/", self.get_params)
        self.assertContains(paypal_response, 'Transaction complete', status_code=200)
        self.assertEqual(len(PayPalPDT.objects.all()), 1)
        pdt_obj = PayPalPDT.objects.all()[0]
        self.assertEqual(pdt_obj.custom, self.get_params['cm'])


class MockedResponse:
    content = 'test'


def mocked_post(*args, **kwargs):
    url = args[0]
    data = kwargs['data']

    assert url == SANDBOX_POSTBACK_ENDPOINT
    assert data['cmd'] == '_notify-synch'
    assert 'at' in data
    assert 'tx' in data

    return MockedResponse()


class PDTPostbackTest(TestCase):
    """
    Tests an actual postback to PayPal server.
    """
    @classmethod
    def setUpClass(cls):
        cls.pdt = PayPalPDT()

    @classmethod
    def tearDownClass(cls):
        pass

    @mock.patch('paypal.standard.pdt.models.requests.post', side_effect=mocked_post)
    def test_postback(self, post):
        response = self.pdt._postback()
        self.assertEqual(response, MockedResponse.content)

    def test_enpoint(self):
        endpoint = self.pdt.get_endpoint()

        if getattr(settings, 'PAYPAL_TEST', True):
            self.assertEqual(endpoint, SANDBOX_POSTBACK_ENDPOINT)
        else:
            self.assertEqual(endpoint, POSTBACK_ENDPOINT)
