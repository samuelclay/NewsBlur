from __future__ import unicode_literals

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.test.utils import override_settings

from paypal.standard.ipn.models import PayPalIPN
from paypal.standard.ipn.signals import valid_ipn_received

from .test_ipn import IPN_POST_PARAMS, IPNUtilsMixin, MockedPostbackMixin

try:
    from django.urls import reverse
except ImportError:
    from django.core.urlresolvers import reverse


@override_settings(ROOT_URLCONF='paypal.standard.ipn.tests.test_urls')
class AdminTest(MockedPostbackMixin, IPNUtilsMixin, TestCase):
    def setUp(self):
        super(AdminTest, self).setUp()
        User = get_user_model()
        user = User.objects.create_superuser(username="admin",
                                             email="admin@example.com",
                                             password="password")
        self.user = user

    def test_verify_action(self):
        PayPalIPN._postback = lambda self: b"Internal Server Error"
        self.paypal_post(IPN_POST_PARAMS)
        ipn_obj = PayPalIPN.objects.get()
        self.assertEqual(ipn_obj.flag, True)

        url = reverse('admin:ipn_paypalipn_changelist')
        self.assertTrue(self.client.login(username='admin',
                                          password='password'))
        response = self.client.get(url)
        self.assertContains(response, IPN_POST_PARAMS['txn_id'])

        self.got_signal = False
        self.signal_obj = None

        def handle_signal(sender, **kwargs):
            self.got_signal = True
            self.signal_obj = sender

        valid_ipn_received.connect(handle_signal)

        PayPalIPN._postback = lambda self: b"VERIFIED"
        response_2 = self.client.post(url,
                                      {'action': 'reverify_flagged',
                                       '_selected_action': [str(ipn_obj.id)]})
        response_3 = self.client.get(response_2['Location'])
        self.assertContains(response_3,
                            "1 IPN object(s) re-verified")

        ipn_obj = PayPalIPN.objects.get()
        self.assertEqual(ipn_obj.flag, False)

        self.assertTrue(self.got_signal)
