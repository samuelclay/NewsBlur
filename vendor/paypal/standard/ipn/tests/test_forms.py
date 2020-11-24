from __future__ import unicode_literals

from django.test import TestCase
from django.test.utils import override_settings

from paypal.standard.forms import PayPalPaymentsForm
from paypal.standard.ipn.forms import PayPalIPNForm


class PaymentsFormTest(TestCase):

    def test_form_render(self):
        return_url = 'https://example.com/return_url'

        f = PayPalPaymentsForm(initial={'business': 'me@mybusiness.com',
                                        'amount': '10.50',
                                        'shipping': '2.00',
                                        'return_url': return_url,
                                        })
        rendered = f.render()
        self.assertIn('''action="https://www.sandbox.paypal.com/cgi-bin/webscr"''', rendered)
        self.assertIn('''value="me@mybusiness.com"''', rendered)
        self.assertIn('''value="2.00"''', rendered)
        self.assertIn('''value="10.50"''', rendered)
        self.assertIn('''buynowCC''', rendered)
        self.assertIn('''value="''' + return_url + '''"''', rendered)

        f = PayPalPaymentsForm(initial={'business': 'me@mybusiness.com',
                                        'amount': '10.50',
                                        'shipping': '2.00',
                                        'return': return_url,
                                        })
        rendered = f.render()
        self.assertIn('''action="https://www.sandbox.paypal.com/cgi-bin/webscr"''', rendered)
        self.assertIn('''value="me@mybusiness.com"''', rendered)
        self.assertIn('''value="2.00"''', rendered)
        self.assertIn('''value="10.50"''', rendered)
        self.assertIn('''buynowCC''', rendered)
        self.assertIn('''value="''' + return_url + '''"''', rendered)

    def test_form_endpont(self):
        with self.settings(PAYPAL_TEST=False):
            f = PayPalPaymentsForm(initial={})
            self.assertNotIn('sandbox', f.render())

    @override_settings(PAYPAL_RECEIVER_EMAIL='me@mybusiness.com')
    def test_form_render_deprecated_paypal_receiver_email(self):
        f = PayPalPaymentsForm(initial={'amount': '10.50',
                                        'shipping': '2.00',
                                        })
        rendered = f.render()
        self.assertIn('''action="https://www.sandbox.paypal.com/cgi-bin/webscr"''', rendered)
        self.assertIn('''value="me@mybusiness.com"''', rendered)
        self.assertIn('''value="2.00"''', rendered)
        self.assertIn('''value="10.50"''', rendered)
        self.assertIn('''buynowCC''', rendered)

    def test_invalid_date_format(self):
        data = {'payment_date': "2015-10-25 01:21:32"}
        form = PayPalIPNForm(data)
        self.assertFalse(form.is_valid())
        self.assertIn(
            form.errors,
            [
                {
                    'payment_date': ['Invalid date format '
                                     '2015-10-25 01:21:32: '
                                     'need more than 2 values to unpack']
                },
                {
                    'payment_date': ['Invalid date format '
                                     '2015-10-25 01:21:32: '
                                     'not enough values to unpack '
                                     '(expected 5, got 2)']
                }
            ]
        )
