from __future__ import unicode_literals

import locale
import unittest
import warnings
from datetime import datetime
from decimal import Decimal

from django.conf import settings
from django.test import TestCase
from django.test.utils import override_settings
from django.utils import timezone
from six import text_type
from six.moves.urllib.parse import urlencode

from paypal.standard.ipn.models import PayPalIPN
from paypal.standard.ipn.signals import (
    invalid_ipn_received, payment_was_flagged, payment_was_refunded, payment_was_reversed, payment_was_successful,
    recurring_cancel, recurring_create, recurring_failed, recurring_payment, recurring_skipped, valid_ipn_received
)
from paypal.standard.ipn.views import CONTENT_TYPE_ERROR
from paypal.standard.models import ST_PP_CANCELLED

# Parameters are all bytestrings, so we can construct a bytestring
# request the same way that Paypal does.

TEST_RECEIVER_EMAIL = b"seller@paypalsandbox.com"

CHARSET = "windows-1252"
IPN_POST_PARAMS = {
    "protection_eligibility": b"Ineligible",
    "last_name": b"User",
    "txn_id": b"51403485VH153354B",
    "receiver_email": TEST_RECEIVER_EMAIL,
    "payment_status": b"Completed",
    "payment_gross": b"10.00",
    "tax": b"0.00",
    "residence_country": b"US",
    "invoice": b"0004",
    "payer_status": b"verified",
    "txn_type": b"express_checkout",
    "handling_amount": b"0.00",
    "payment_date": b"23:04:06 Feb 02, 2009 PST",
    "first_name": b"J\xF6rg",
    "item_name": b"",
    "charset": CHARSET.encode('ascii'),
    "custom": b"website_id=13&user_id=21",
    "notify_version": b"2.6",
    "transaction_subject": b"",
    "test_ipn": b"1",
    "item_number": b"",
    "receiver_id": b"258DLEHY2BDK6",
    "payer_id": b"BN5JZ2V7MLEV4",
    "verify_sign": b"An5ns1Kso7MWUdW4ErQKJJJ4qi4-AqdZy6dD.sGO3sDhTf1wAbuO2IZ7",
    "payment_fee": b"0.59",
    "mc_fee": b"0.59",
    "mc_currency": b"USD",
    "shipping": b"0.00",
    "payer_email": b"bishan_1233269544_per@gmail.com",
    "payment_type": b"instant",
    "mc_gross": b"10.00",
    "quantity": b"1",
}


class ResetIPNSignalsMixin(object):
    def setUp(self):
        super(ResetIPNSignalsMixin, self).setUp()
        self.valid_ipn_received_receivers = valid_ipn_received.receivers
        self.invalid_ipn_received_receivers = invalid_ipn_received.receivers
        # Deprecated:
        self.payment_was_successful_receivers = payment_was_successful.receivers
        self.payment_was_flagged_receivers = payment_was_flagged.receivers
        self.payment_was_refunded_receivers = payment_was_refunded.receivers
        self.payment_was_reversed_receivers = payment_was_reversed.receivers
        self.recurring_skipped_receivers = recurring_skipped.receivers
        self.recurring_failed_receivers = recurring_failed.receivers
        self.recurring_create_receivers = recurring_create.receivers
        self.recurring_payment_receivers = recurring_payment.receivers
        self.recurring_cancel_receivers = recurring_cancel.receivers

        valid_ipn_received.receivers = []
        invalid_ipn_received.receivers = []
        # Deprecated:
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
        valid_ipn_received.receivers = self.valid_ipn_received_receivers
        invalid_ipn_received.receivers = self.invalid_ipn_received_receivers

        payment_was_successful.receivers = self.payment_was_successful_receivers
        payment_was_flagged.receivers = self.payment_was_flagged_receivers
        payment_was_refunded.receivers = self.payment_was_refunded_receivers
        payment_was_reversed.receivers = self.payment_was_reversed_receivers
        recurring_skipped.receivers = self.recurring_skipped_receivers
        recurring_failed.receivers = self.recurring_failed_receivers
        recurring_create.receivers = self.recurring_create_receivers
        recurring_payment.receivers = self.recurring_payment_receivers
        recurring_cancel.receivers = self.recurring_cancel_receivers
        super(ResetIPNSignalsMixin, self).tearDown()


class IPNUtilsMixin(ResetIPNSignalsMixin):
    def paypal_post(self, params):
        """
        Does an HTTP POST the way that PayPal does, using the params given.
        """
        # We build params into a bytestring ourselves, to avoid some encoding
        # processing that is done by the test client.
        cond_encode = lambda v: v.encode(CHARSET) if isinstance(v, text_type) else v
        byte_params = {cond_encode(k): cond_encode(v) for k, v in params.items()}
        post_data = urlencode(byte_params)
        return self.client.post("/ipn/", post_data, content_type='application/x-www-form-urlencoded')

    def assertGotSignal(self, signal, flagged, params=IPN_POST_PARAMS, deprecated=False):
        # Check the signal was sent. These get lost if they don't reference self.
        self.got_signal = False
        self.signal_obj = None

        def handle_signal(sender, **kwargs):
            self.got_signal = True
            self.signal_obj = sender

        if deprecated:
            with warnings.catch_warnings(record=True) as w:
                warnings.simplefilter("always")
                signal.connect(handle_signal)
        else:
            signal.connect(handle_signal)

        response = self.paypal_post(params)
        self.assertEqual(response.status_code, 200)
        ipns = PayPalIPN.objects.all()
        self.assertEqual(len(ipns), 1)
        ipn_obj = ipns[0]
        self.assertEqual(ipn_obj.flag, flagged)

        self.assertTrue(self.got_signal)
        self.assertEqual(self.signal_obj, ipn_obj)
        if deprecated:
            self.assertEqual(len([r for r in w if r.category == DeprecationWarning]), 1)
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


class MockedPostbackMixin(object):
    def setUp(self):
        super(MockedPostbackMixin, self).setUp()
        # Monkey patch over PayPalIPN to make it get a VERFIED response.
        self.old_postback = PayPalIPN._postback
        PayPalIPN._postback = lambda self: b"VERIFIED"

    def tearDown(self):
        PayPalIPN._postback = self.old_postback
        super(MockedPostbackMixin, self).tearDown()


@override_settings(ROOT_URLCONF='paypal.standard.ipn.tests.test_urls')
class IPNTest(MockedPostbackMixin, IPNUtilsMixin, TestCase):

    def test_valid_ipn_received(self):
        ipn_obj = self.assertGotSignal(valid_ipn_received, False)
        # Check some encoding issues:
        self.assertEqual(ipn_obj.first_name, u"J\u00f6rg")
        # Check date parsing
        self.assertEqual(ipn_obj.payment_date,
                         datetime(2009, 2, 3, 7, 4, 6,
                                  tzinfo=timezone.utc if settings.USE_TZ else None))

    def test_invalid_ipn_received(self):
        PayPalIPN._postback = lambda self: b"INVALID"
        self.assertGotSignal(invalid_ipn_received, True)

    def test_reverify_ipn(self):
        PayPalIPN._postback = lambda self: b"Internal Server Error"
        self.paypal_post(IPN_POST_PARAMS)
        ipn_obj = PayPalIPN.objects.all()[0]
        self.assertEqual(ipn_obj.flag, True)
        PayPalIPN._postback = lambda self: b"VERIFIED"
        ipn_obj.verify()
        self.assertEqual(ipn_obj.flag, False)
        self.assertEqual(ipn_obj.flag_info, "")
        self.assertEqual(ipn_obj.flag_code, "")

    def test_payment_was_successful(self):
        self.assertGotSignal(payment_was_successful, False, deprecated=True)

    def test_payment_was_flagged(self):
        PayPalIPN._postback = lambda self: b"INVALID"
        self.assertGotSignal(payment_was_flagged, True, deprecated=True)

    def test_refunded_ipn(self):
        update = {
            "payment_status": "Refunded"
        }
        params = IPN_POST_PARAMS.copy()
        params.update(update)

        self.assertGotSignal(payment_was_refunded, False, params, deprecated=True)

    def test_with_na_date(self):
        update = {
            "payment_status": "Refunded",
            "time_created": "N/A"
        }
        params = IPN_POST_PARAMS.copy()
        params.update(update)

        self.assertGotSignal(payment_was_refunded, False, params, deprecated=True)

    def test_reversed_ipn(self):
        update = {
            "payment_status": "Reversed"
        }
        params = IPN_POST_PARAMS.copy()
        params.update(update)

        self.assertGotSignal(payment_was_reversed, False, params, deprecated=True)

    @override_settings(PAYPAL_RECEIVER_EMAIL=TEST_RECEIVER_EMAIL)
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

    def test_duplicate_txn_id_with_first_flagged(self):
        PayPalIPN._postback = lambda self: b"Internal Server Error"
        self.paypal_post(IPN_POST_PARAMS)
        PayPalIPN._postback = lambda self: b"VERIFIED"
        self.paypal_post(IPN_POST_PARAMS)
        self.assertEqual(len(PayPalIPN.objects.all()), 2)
        ipn_objs = PayPalIPN.objects.order_by('created_at', 'pk')
        self.assertEqual(ipn_objs[0].flag, True)
        self.assertEqual(ipn_objs[1].flag, False)

    def test_recurring_payment_skipped_ipn(self):
        update = {
            "recurring_payment_id": "BN5JZ2V7MLEV4",
            "txn_type": "recurring_payment_skipped",
            "txn_id": ""
        }
        params = IPN_POST_PARAMS.copy()
        params.update(update)

        self.assertGotSignal(recurring_skipped, False, params, deprecated=True)

    def test_recurring_payment_failed_ipn(self):
        update = {
            "recurring_payment_id": "BN5JZ2V7MLEV4",
            "txn_type": "recurring_payment_failed",
            "txn_id": ""
        }
        params = IPN_POST_PARAMS.copy()
        params.update(update)

        self.assertGotSignal(recurring_failed, False, params, deprecated=True)

    def test_recurring_payment_create_ipn(self):
        update = {
            "recurring_payment_id": "BN5JZ2V7MLEV4",
            "txn_type": "recurring_payment_profile_created",
            "txn_id": ""
        }
        params = IPN_POST_PARAMS.copy()
        params.update(update)

        self.assertGotSignal(recurring_create, False, params, deprecated=True)

    def test_recurring_payment_cancel_ipn(self):
        update = {
            "recurring_payment_id": "BN5JZ2V7MLEV4",
            "txn_type": "recurring_payment_profile_cancel",
            "txn_id": ""
        }
        params = IPN_POST_PARAMS.copy()
        params.update(update)

        self.assertGotSignal(recurring_cancel, False, params, deprecated=True)

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

        with warnings.catch_warnings(record=True):
            recurring_payment.connect(handle_signal)
        response = self.paypal_post(params)
        self.assertEqual(response.status_code, 200)
        ipns = PayPalIPN.objects.all()
        self.assertEqual(len(ipns), 1)
        self.assertFalse(self.got_signal)

    def test_posted_params_attribute(self):
        params = {'btn_id1': b"3453595",
                  'business': b"email-facilitator@gmail.com",
                  'charset': b"windows-1252",
                  'custom': b"blahblah",
                  "first_name": b"J\xF6rg",
                  'ipn_track_id': b"a48170aadb705",
                  'item_name1': b"Romanescoins",
                  'item_number1': b"",
                  'last_name': b"LASTNAME",
                  'mc_currency': b"EUR",
                  'mc_fee': b"0.35",
                  'mc_gross': b"3.00",
                  'mc_gross_1': b"3.00",
                  'mc_handling': b"0.00",
                  'mc_handling1': b"0.00",
                  'mc_shipping': b"0.00",
                  'mc_shipping1': b"0.00",
                  'notify_version': b"3.8",
                  'num_cart_items': b"1",
                  'payer_email': b"email@gmail.com",
                  'payer_id': b"6EQ6SKDFMPU36",
                  'payer_status': b"verified",
                  'payment_date': b"03:06:57 Jun 27, 2014 PDT",
                  'payment_fee': b"",
                  'payment_gross': b"",
                  'payment_status': b"Completed",
                  'payment_type': b"instant",
                  'protection_eligibility': b"Ineligible",
                  'quantity1': b"3",
                  'receiver_email': b"email-facilitator@gmail.com",
                  'receiver_id': b"UCWM6R2TARF36",
                  'residence_country': b"FR",
                  'tax': b"0.00",
                  'tax1': b"0.00",
                  'test_ipn': b"1",
                  'transaction_subject': b"blahblah",
                  'txn_id': b"KW31266C37C2593K4",
                  'txn_type': b"cart",
                  'verify_sign': b"A_SECRET_CODE"}
        self.paypal_post(params)
        ipn = PayPalIPN.objects.get()
        self.assertEqual(ipn.posted_data_dict['quantity1'], '3')
        self.assertEqual(ipn.posted_data_dict['first_name'], u"J\u00f6rg")

    def test_paypal_date_format(self):
        update = {
            "next_payment_date": b"23:04:06 Feb 02, 2009 PST",
            "subscr_date": b"23:04:06 Jan 02, 2009 PST",
            "subscr_effective": b"23:04:06 Jan 02, 2009 PST",
            "auction_closing_date": b"23:04:06 Jan 02, 2009 PST",
            "retry_at": b"23:04:06 Jan 02, 2009 PST",
            # test parsing times in PST/PDT change period
            "case_creation_date": b"01:13:05 Nov 01, 2015 PST",
            "time_created": b"01:13:05 Nov 01, 2015 PDT",
        }

        params = IPN_POST_PARAMS.copy()
        params.update(update)

        self.paypal_post(params)
        self.assertFalse(PayPalIPN.objects.get().flag)

    def test_paypal_date_invalid_format(self):
        params = IPN_POST_PARAMS.copy()
        params.update({"time_created": b"2015-10-25 01:21:32"})
        self.paypal_post(params)
        self.assertTrue(PayPalIPN.objects.latest('id').flag)
        self.assertIn(
            PayPalIPN.objects.latest('id').flag_info,
            ['Invalid form. (time_created: Invalid date format '
             '2015-10-25 01:21:32: need more than 2 values to unpack)',
             'Invalid form. (time_created: Invalid date format '
             '2015-10-25 01:21:32: not enough values to unpack '
             '(expected 5, got 2))'
             ]
        )

        # day not int convertible
        params = IPN_POST_PARAMS.copy()
        params.update({"payment_date": b"01:21:32 Jan 25th 2015 PDT"})
        self.paypal_post(params)
        self.assertTrue(PayPalIPN.objects.latest('id').flag)
        self.assertEqual(
            PayPalIPN.objects.latest('id').flag_info,
            "Invalid form. (payment_date: Invalid date format "
            "01:21:32 Jan 25th 2015 PDT: invalid literal for int() with "
            "base 10: '25th')"
        )

        # month not in Mmm format
        params = IPN_POST_PARAMS.copy()
        params.update({"next_payment_date": b"01:21:32 01 25 2015 PDT"})
        self.paypal_post(params)
        self.assertTrue(PayPalIPN.objects.latest('id').flag)
        self.assertIn(
            PayPalIPN.objects.latest('id').flag_info,
            ["Invalid form. (next_payment_date: Invalid date format "
             "01:21:32 01 25 2015 PDT: u'01' is not in list)",
             "Invalid form. (next_payment_date: Invalid date format "
             "01:21:32 01 25 2015 PDT: '01' is not in list)"]
        )

        # month not in Mmm format
        params = IPN_POST_PARAMS.copy()
        params.update({"retry_at": b"01:21:32 January 25 2015 PDT"})
        self.paypal_post(params)
        self.assertTrue(PayPalIPN.objects.latest('id').flag)
        self.assertIn(
            PayPalIPN.objects.latest('id').flag_info,
            ["Invalid form. (retry_at: Invalid date format "
             "01:21:32 January 25 2015 PDT: u'January' is not in list)",
             "Invalid form. (retry_at: Invalid date format "
             "01:21:32 January 25 2015 PDT: 'January' is not in list)"]
        )

        # no seconds in time part
        params = IPN_POST_PARAMS.copy()
        params.update({"subscr_date": b"01:28 Jan 25 2015 PDT"})
        self.paypal_post(params)
        self.assertTrue(PayPalIPN.objects.latest('id').flag)
        self.assertIn(
            PayPalIPN.objects.latest('id').flag_info,
            ["Invalid form. (subscr_date: Invalid date format "
             "01:28 Jan 25 2015 PDT: need more than 2 values to unpack)",
             "Invalid form. (subscr_date: Invalid date format "
             "01:28 Jan 25 2015 PDT: not enough values to unpack "
             "(expected 3, got 2))"]
        )

        # string not valid datetime
        params = IPN_POST_PARAMS.copy()
        params.update({"case_creation_date": b"01:21:32 Jan 49 2015 PDT"})
        self.paypal_post(params)
        self.assertTrue(PayPalIPN.objects.latest('id').flag)
        self.assertEqual(
            PayPalIPN.objects.latest('id').flag_info,
            "Invalid form. (case_creation_date: Invalid date format "
            "01:21:32 Jan 49 2015 PDT: day is out of range for month)"
        )

    def test_content_type_validation(self):
        with self.assertRaises(AssertionError) as assert_context:
            self.client.post("/ipn/", {}, content_type='application/json')
        self.assertIn(CONTENT_TYPE_ERROR, repr(assert_context.exception)),
        self.assertFalse(PayPalIPN.objects.exists())


@override_settings(ROOT_URLCONF='paypal.standard.ipn.tests.test_urls')
class IPNLocaleTest(IPNUtilsMixin, MockedPostbackMixin, TestCase):
    def setUp(self):
        self.old_locale = locale.getlocale(locale.LC_TIME)
        try:
            locale.setlocale(locale.LC_TIME, ('fr_FR', 'UTF-8'))
        except Exception:
            raise unittest.SkipTest("fr_FR locale not available for testing")
        # Put super call at the end, so that it isn't called if we skip the test
        # (since tearDown is not called in that case).
        super(IPNLocaleTest, self).setUp()

    def tearDown(self):
        locale.setlocale(locale.LC_TIME, self.old_locale)
        super(IPNLocaleTest, self).tearDown()

    def test_valid_ipn_received(self):
        ipn_obj = self.assertGotSignal(valid_ipn_received, False)
        self.assertEqual(ipn_obj.last_name, u"User")
        # Check date parsing
        self.assertEqual(ipn_obj.payment_date,
                         datetime(2009, 2, 3, 7, 4, 6,
                                  tzinfo=timezone.utc if settings.USE_TZ else None))


@override_settings(ROOT_URLCONF='paypal.standard.ipn.tests.test_urls')
class IPNPostbackTest(IPNUtilsMixin, TestCase):
    """
    Tests an actual postback to PayPal server.
    """
    def test_postback(self):
        # Incorrect signature means we will always get failure
        self.assertFlagged({}, u'Invalid postback. (INVALID)')


@override_settings(ROOT_URLCONF='paypal.standard.ipn.tests.test_urls')
class IPNSimulatorTests(TestCase):

    # Some requests, as sent by the simulator.

    # The simulator itself has bugs. For example, it doesn't send the 'charset'
    # parameter, unlike in production. We could wait for PayPal to fix these
    # bugs... ha ha, only kidding! If developers want to use the simulator, we
    # need to deal with whatever it sends.

    def get_ipn(self):
        return PayPalIPN.objects.all().get()

    def post_to_ipn_handler(self, post_data):
        return self.client.post("/ipn/", post_data, content_type='application/x-www-form-urlencoded')

    def test_valid_webaccept(self):
        paypal_input = b'payment_type=instant&payment_date=23%3A04%3A06%20Feb%2002%2C%202009%20PDT&' \
                       b'payment_status=Completed&address_status=confirmed&payer_status=verified&' \
                       b'first_name=John&last_name=Smith&payer_email=buyer%40paypalsandbox.com&' \
                       b'payer_id=TESTBUYERID01&address_name=John%20Smith&address_country=United%20States&' \
                       b'address_country_code=US&address_zip=95131&address_state=CA&address_city=San%20Jose&' \
                       b'address_street=123%20any%20street&business=seller%40paypalsandbox.com&' \
                       b'receiver_email=seller%40paypalsandbox.com&receiver_id=seller%40paypalsandbox.com&' \
                       b'residence_country=US&item_name=something&item_number=AK-1234&quantity=1&shipping=3.04&' \
                       b'tax=2.02&mc_currency=USD&mc_fee=0.44&mc_gross=12.34&mc_gross1=12.34&txn_type=web_accept&' \
                       b'txn_id=593976436&notify_version=2.1&custom=xyz123&invoice=abc1234&test_ipn=1&' \
                       b'verify_sign=AFcWxV21C7fd0v3bYYYRCpSSRl31Awsh54ABFpebxm5s9x58YIW-AWIb'
        response = self.post_to_ipn_handler(paypal_input)
        self.assertEqual(response.status_code, 200)
        ipn = self.get_ipn()
        self.assertFalse(ipn.flag)
        self.assertEqual(ipn.mc_gross, Decimal("12.34"))
        # For tests, we get conversion to UTC because this is all SQLite supports.
        self.assertEqual(ipn.payment_date, datetime(2009, 2, 3, 7, 4, 6,
                                                    tzinfo=timezone.utc if settings.USE_TZ else None))

    def test_declined(self):
        paypal_input = b'payment_type=instant&payment_date=23%3A04%3A06%20Feb%2002%2C%202009%20PDT&' \
                       b'payment_status=Declined&address_status=confirmed&payer_status=verified&' \
                       b'first_name=John&last_name=Smith&payer_email=buyer%40paypalsandbox.com&' \
                       b'payer_id=TESTBUYERID01&address_name=John%20Smith&address_country=United%20States&' \
                       b'address_country_code=US&address_zip=95131&address_state=CA&address_city=San%20Jose&' \
                       b'address_street=123%20any%20street&business=seller%40paypalsandbox.com&' \
                       b'receiver_email=seller%40paypalsandbox.com&receiver_id=seller%40paypalsandbox.com&' \
                       b'residence_country=US&item_name=something&item_number=AK-1234&quantity=1&shipping=3.04&' \
                       b'tax=2.02&mc_currency=USD&mc_fee=0.44&mc_gross=131.22&mc_gross1=131.22&txn_type=web_accept&' \
                       b'txn_id=153826001&notify_version=2.1&custom=xyz123&invoice=abc1234&test_ipn=1&' \
                       b'verify_sign=AiPC9BjkCyDFQXbSkoZcgqH3hpacAIG977yabdROlR9d0bf98jevF2-i'
        self.post_to_ipn_handler(paypal_input)
        ipn = self.get_ipn()
        self.assertFalse(ipn.flag)
