from django.conf import settings
from django.test import TestCase
from six import b
from six.moves.urllib.parse import urlencode

from paypal.standard.models import ST_PP_CANCELLED
from paypal.standard.ipn.models import PayPalIPN
from paypal.standard.ipn.signals import (payment_was_successful,
                                         payment_was_flagged, payment_was_refunded, payment_was_reversed,
                                         recurring_skipped, recurring_failed,
                                         recurring_create, recurring_payment, recurring_cancel)


# Parameters are all bytestrings, so we can construct a bytestring
# request the same way that Paypal does.

IPN_POST_PARAMS = {
    "protection_eligibility": b("Ineligible"),
    "last_name": b("User"),
    "txn_id": b("51403485VH153354B"),
    "receiver_email": b(settings.PAYPAL_RECEIVER_EMAIL),
    "payment_status": b("Completed"),
    "payment_gross": b("10.00"),
    "tax": b("0.00"),
    "residence_country": b("US"),
    "invoice": b("0004"),
    "payer_status": b("verified"),
    "txn_type": b("express_checkout"),
    "handling_amount": b("0.00"),
    "payment_date": b("23:04:06 Feb 02, 2009 PST"),
    "first_name": b("J\xF6rg"),
    "item_name": b(""),
    "charset": b("windows-1252"),
    "custom": b("website_id=13&user_id=21"),
    "notify_version": b("2.6"),
    "transaction_subject": b(""),
    "test_ipn": b("1"),
    "item_number": b(""),
    "receiver_id": b("258DLEHY2BDK6"),
    "payer_id": b("BN5JZ2V7MLEV4"),
    "verify_sign": b("An5ns1Kso7MWUdW4ErQKJJJ4qi4-AqdZy6dD.sGO3sDhTf1wAbuO2IZ7"),
    "payment_fee": b("0.59"),
    "mc_fee": b("0.59"),
    "mc_currency": b("USD"),
    "shipping": b("0.00"),
    "payer_email": b("bishan_1233269544_per@gmail.com"),
    "payment_type": b("instant"),
    "mc_gross": b("10.00"),
    "quantity": b("1"),
}


class IPNTestBase(TestCase):
    urls = 'paypal.standard.ipn.tests.test_urls'

    def setUp(self):
        self.payment_was_successful_receivers = payment_was_successful.receivers
        self.payment_was_flagged_receivers = payment_was_flagged.receivers
        self.payment_was_refunded_receivers = payment_was_refunded.receivers
        self.payment_was_reversed_receivers = payment_was_reversed.receivers
        self.recurring_skipped_receivers = recurring_skipped.receivers
        self.recurring_failed_receivers = recurring_failed.receivers
        self.recurring_create_receivers = recurring_create.receivers
        self.recurring_payment_receivers = recurring_payment.receivers
        self.recurring_cancel_receivers = recurring_cancel.receivers

        payment_was_successful.receivers = []
        payment_was_flagged.receivers = []
        payment_was_refunded.receivers = []
        payment_was_reversed.receivers = []
        recurring_skipped.receivers = []
        recurring_failed.receivers = []
        recurring_create.receivers = []
        recurring_payment.receivers = []
        recurring_cancel.receivers = []

    def tearDown(self):
        payment_was_successful.receivers = self.payment_was_successful_receivers
        payment_was_flagged.receivers = self.payment_was_flagged_receivers
        payment_was_refunded.receivers = self.payment_was_refunded_receivers
        payment_was_reversed.receivers = self.payment_was_reversed_receivers
        recurring_skipped.receivers = self.recurring_skipped_receivers
        recurring_failed.receivers = self.recurring_failed_receivers
        recurring_create.receivers = self.recurring_create_receivers
        recurring_payment.receivers = self.recurring_payment_receivers
        recurring_cancel.receivers = self.recurring_cancel_receivers

    def paypal_post(self, params):
        """
        Does an HTTP POST the way that PayPal does, using the params given.
        """
        # We build params into a bytestring ourselves, to avoid some encoding
        # processing that is done by the test client.
        post_data = urlencode(params)
        return self.client.post("/ipn/", post_data, content_type='application/x-www-form-urlencoded')

    def assertGotSignal(self, signal, flagged, params=IPN_POST_PARAMS):
        # Check the signal was sent. These get lost if they don't reference self.
        self.got_signal = False
        self.signal_obj = None

        def handle_signal(sender, **kwargs):
            self.got_signal = True
            self.signal_obj = sender

        signal.connect(handle_signal)
        response = self.paypal_post(params)
        self.assertEqual(response.status_code, 200)
        ipns = PayPalIPN.objects.all()
        self.assertEqual(len(ipns), 1)
        ipn_obj = ipns[0]
        self.assertEqual(ipn_obj.flag, flagged)

        self.assertTrue(self.got_signal)
        self.assertEqual(self.signal_obj, ipn_obj)
        return ipn_obj

    def assertFlagged(self, updates, flag_info):
        params = IPN_POST_PARAMS.copy()
        params.update(updates)
        response = self.paypal_post(params)
        self.assertEqual(response.status_code, 200)
        ipn_obj = PayPalIPN.objects.all()[0]
        self.assertEqual(ipn_obj.flag, True)
        self.assertEqual(ipn_obj.flag_info, flag_info)
        return ipn_obj


class IPNTest(IPNTestBase):

    def setUp(self):
        # Monkey patch over PayPalIPN to make it get a VERFIED response.
        self.old_postback = PayPalIPN._postback
        PayPalIPN._postback = lambda self: b("VERIFIED")

    def tearDown(self):
        PayPalIPN._postback = self.old_postback

    def test_correct_ipn(self):
        ipn_obj = self.assertGotSignal(payment_was_successful, False)
        # Check some encoding issues:
        self.assertEqual(ipn_obj.first_name, u"J\u00f6rg")

    def test_failed_ipn(self):
        PayPalIPN._postback = lambda self: b("INVALID")
        self.assertGotSignal(payment_was_flagged, True)

    def test_ipn_missing_charset(self):
        params = IPN_POST_PARAMS.copy()
        del params['charset']
        self.assertGotSignal(payment_was_flagged, True, params=params)

    def test_refunded_ipn(self):
        update = {
            "payment_status": "Refunded"
        }
        params = IPN_POST_PARAMS.copy()
        params.update(update)

        self.assertGotSignal(payment_was_refunded, False, params)

    def test_with_na_date(self):
        update = {
            "payment_status": "Refunded",
            "time_created": "N/A"
        }
        params = IPN_POST_PARAMS.copy()
        params.update(update)

        self.assertGotSignal(payment_was_refunded, False, params)

    def test_reversed_ipn(self):
        update = {
            "payment_status": "Reversed"
        }
        params = IPN_POST_PARAMS.copy()
        params.update(update)

        self.assertGotSignal(payment_was_reversed, False, params)

    def test_incorrect_receiver_email(self):
        update = {"receiver_email": "incorrect_email@someotherbusiness.com"}
        flag_info = "Invalid receiver_email. (incorrect_email@someotherbusiness.com)"
        self.assertFlagged(update, flag_info)

    def test_invalid_payment_status(self):
        update = {"payment_status": "Failure"}
        flag_info = u"Invalid payment_status. (Failure)"
        self.assertFlagged(update, flag_info)

    def test_vaid_payment_status_cancelled(self):
        update = {"payment_status": ST_PP_CANCELLED}
        params = IPN_POST_PARAMS.copy()
        params.update(update)
        response = self.paypal_post(params)
        self.assertEqual(response.status_code, 200)
        ipn_obj = PayPalIPN.objects.all()[0]
        self.assertEqual(ipn_obj.flag, False)

    def test_duplicate_txn_id(self):
        self.paypal_post(IPN_POST_PARAMS)
        self.paypal_post(IPN_POST_PARAMS)
        self.assertEqual(len(PayPalIPN.objects.all()), 2)
        ipn_obj = PayPalIPN.objects.order_by('-created_at', '-pk')[0]
        self.assertEqual(ipn_obj.flag, True)
        self.assertEqual(ipn_obj.flag_info, "Duplicate txn_id. (51403485VH153354B)")

    def test_recurring_payment_skipped_ipn(self):
        update = {
            "recurring_payment_id": "BN5JZ2V7MLEV4",
            "txn_type": "recurring_payment_skipped",
            "txn_id": ""
        }
        params = IPN_POST_PARAMS.copy()
        params.update(update)

        self.assertGotSignal(recurring_skipped, False, params)

    def test_recurring_payment_failed_ipn(self):
        update = {
            "recurring_payment_id": "BN5JZ2V7MLEV4",
            "txn_type": "recurring_payment_failed",
            "txn_id": ""
        }
        params = IPN_POST_PARAMS.copy()
        params.update(update)

        self.assertGotSignal(recurring_failed, False, params)

    def test_recurring_payment_create_ipn(self):
        update = {
            "recurring_payment_id": "BN5JZ2V7MLEV4",
            "txn_type": "recurring_payment_profile_created",
            "txn_id": ""
        }
        params = IPN_POST_PARAMS.copy()
        params.update(update)

        self.assertGotSignal(recurring_create, False, params)

    def test_recurring_payment_cancel_ipn(self):
        update = {
            "recurring_payment_id": "BN5JZ2V7MLEV4",
            "txn_type": "recurring_payment_profile_cancel",
            "txn_id": ""
        }
        params = IPN_POST_PARAMS.copy()
        params.update(update)

        self.assertGotSignal(recurring_cancel, False, params)

    def test_recurring_payment_ipn(self):
        """
        The wat the code is written in
        PayPalIPN.send_signals the recurring_payment
        will never be sent because the paypal ipn
        contains a txn_id, if this test failes you
        might break some compatibility
        """
        update = {
            "recurring_payment_id": "BN5JZ2V7MLEV4",
            "txn_type": "recurring_payment",
        }
        params = IPN_POST_PARAMS.copy()
        params.update(update)

        self.got_signal = False
        self.signal_obj = None

        def handle_signal(sender, **kwargs):
            self.got_signal = True
            self.signal_obj = sender

        recurring_payment.connect(handle_signal)
        response = self.paypal_post(params)
        self.assertEqual(response.status_code, 200)
        ipns = PayPalIPN.objects.all()
        self.assertEqual(len(ipns), 1)
        self.assertFalse(self.got_signal)

    def test_posted_params_attribute(self):
        params = {'btn_id1': b('3453595'),
                  'business': b('email-facilitator@gmail.com'),
                  'charset': b('windows-1252'),
                  'custom': b('blahblah'),
                  "first_name": b("J\xF6rg"),
                  'ipn_track_id': b('a48170aadb705'),
                  'item_name1': b('Romanescoins'),
                  'item_number1': b(''),
                  'last_name': b('LASTNAME'),
                  'mc_currency': b('EUR'),
                  'mc_fee': b('0.35'),
                  'mc_gross': b('3.00'),
                  'mc_gross_1': b('3.00'),
                  'mc_handling': b('0.00'),
                  'mc_handling1': b('0.00'),
                  'mc_shipping': b('0.00'),
                  'mc_shipping1': b('0.00'),
                  'notify_version': b('3.8'),
                  'num_cart_items': b('1'),
                  'payer_email': b('email@gmail.com'),
                  'payer_id': b('6EQ6SKDFMPU36'),
                  'payer_status': b('verified'),
                  'payment_date': b('03:06:57 Jun 27, 2014 PDT'),
                  'payment_fee': b(''),
                  'payment_gross': b(''),
                  'payment_status': b('Completed'),
                  'payment_type': b('instant'),
                  'protection_eligibility': b('Ineligible'),
                  'quantity1': b('3'),
                  'receiver_email': b('email-facilitator@gmail.com'),
                  'receiver_id': b('UCWM6R2TARF36'),
                  'residence_country': b('FR'),
                  'tax': b('0.00'),
                  'tax1': b('0.00'),
                  'test_ipn': b('1'),
                  'transaction_subject': b('blahblah'),
                  'txn_id': b('KW31266C37C2593K4'),
                  'txn_type': b('cart'),
                  'verify_sign': b('A_SECRET_CODE')}
        self.paypal_post(params)
        ipn = PayPalIPN.objects.get()
        self.assertEqual(ipn.posted_data_dict['quantity1'], '3')
        self.assertEqual(ipn.posted_data_dict['first_name'], u"J\u00f6rg")

class IPNPostbackTest(IPNTestBase):
    """
    Tests an actual postback to PayPal server.
    """
    def test_postback(self):
        # Incorrect signature means we will always get failure
        self.assertFlagged({}, u'Invalid postback. (INVALID)')
