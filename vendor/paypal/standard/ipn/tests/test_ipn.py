from django.conf import settings
from django.http import HttpResponse
from django.test import TestCase
from django.test.client import Client

from paypal.standard.ipn.models import PayPalIPN
from paypal.standard.ipn.signals import (payment_was_successful, 
    payment_was_flagged)


IPN_POST_PARAMS = {
    "protection_eligibility": "Ineligible",
    "last_name": "User",
    "txn_id": "51403485VH153354B",
    "receiver_email": settings.PAYPAL_RECEIVER_EMAIL,
    "payment_status": "Completed",
    "payment_gross": "10.00",
    "tax": "0.00",
    "residence_country": "US",
    "invoice": "0004",
    "payer_status": "verified",
    "txn_type": "express_checkout",
    "handling_amount": "0.00",
    "payment_date": "23:04:06 Feb 02, 2009 PST",
    "first_name": "Test",
    "item_name": "",
    "charset": "windows-1252",
    "custom": "website_id=13&user_id=21",
    "notify_version": "2.6",
    "transaction_subject": "",
    "test_ipn": "1",
    "item_number": "",
    "receiver_id": "258DLEHY2BDK6",
    "payer_id": "BN5JZ2V7MLEV4",
    "verify_sign": "An5ns1Kso7MWUdW4ErQKJJJ4qi4-AqdZy6dD.sGO3sDhTf1wAbuO2IZ7",
    "payment_fee": "0.59",
    "mc_fee": "0.59",
    "mc_currency": "USD",
    "shipping": "0.00",
    "payer_email": "bishan_1233269544_per@gmail.com",
    "payment_type": "instant",
    "mc_gross": "10.00",
    "quantity": "1",
}


class IPNTest(TestCase):    
    urls = 'paypal.standard.ipn.tests.test_urls'

    def setUp(self):
        self.old_debug = settings.DEBUG
        settings.DEBUG = True

        # Monkey patch over PayPalIPN to make it get a VERFIED response.
        self.old_postback = PayPalIPN._postback
        PayPalIPN._postback = lambda self: "VERIFIED"
        
    def tearDown(self):
        settings.DEBUG = self.old_debug
        PayPalIPN._postback = self.old_postback

    def assertGotSignal(self, signal, flagged):
        # Check the signal was sent. These get lost if they don't reference self.
        self.got_signal = False
        self.signal_obj = None
        
        def handle_signal(sender, **kwargs):
            self.got_signal = True
            self.signal_obj = sender
        signal.connect(handle_signal)
        
        response = self.client.post("/ipn/", IPN_POST_PARAMS)
        self.assertEqual(response.status_code, 200)
        ipns = PayPalIPN.objects.all()
        self.assertEqual(len(ipns), 1)        
        ipn_obj = ipns[0]        
        self.assertEqual(ipn_obj.flag, flagged)
        
        self.assertTrue(self.got_signal)
        self.assertEqual(self.signal_obj, ipn_obj)
        
    def test_correct_ipn(self):
        self.assertGotSignal(payment_was_successful, False)

    def test_failed_ipn(self):
        PayPalIPN._postback = lambda self: "INVALID"
        self.assertGotSignal(payment_was_flagged, True)

    def assertFlagged(self, updates, flag_info):
        params = IPN_POST_PARAMS.copy()
        params.update(updates)
        response = self.client.post("/ipn/", params)
        self.assertEqual(response.status_code, 200)
        ipn_obj = PayPalIPN.objects.all()[0]
        self.assertEqual(ipn_obj.flag, True)
        self.assertEqual(ipn_obj.flag_info, flag_info)

    def test_incorrect_receiver_email(self):
        update = {"receiver_email": "incorrect_email@someotherbusiness.com"}
        flag_info = "Invalid receiver_email. (incorrect_email@someotherbusiness.com)"
        self.assertFlagged(update, flag_info)

    def test_invalid_payment_status(self):
        update = {"payment_status": "Failed"}
        flag_info = "Invalid payment_status. (Failed)"
        self.assertFlagged(update, flag_info)

    def test_duplicate_txn_id(self):       
        self.client.post("/ipn/", IPN_POST_PARAMS)
        self.client.post("/ipn/", IPN_POST_PARAMS)
        self.assertEqual(len(PayPalIPN.objects.all()), 2)
        ipn_obj = PayPalIPN.objects.order_by('-created_at')[1]
        self.assertEqual(ipn_obj.flag, True)
        self.assertEqual(ipn_obj.flag_info, "Duplicate txn_id. (51403485VH153354B)")