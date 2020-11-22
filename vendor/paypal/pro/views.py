#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import unicode_literals

import warnings

from django.http import HttpResponseRedirect
from django.template.response import TemplateResponse

from paypal.pro.exceptions import PayPalFailure
from paypal.pro.forms import ConfirmForm, PaymentForm
from paypal.pro.helpers import PayPalWPP, express_endpoint_for_token
from paypal.utils import warn_untested


class PayPalPro(object):
    """
    This class-based view takes care of PayPal WebsitePaymentsPro (WPP).
    PayPalPro has two separate flows - DirectPayment and ExpressPayFlow. In
    DirectPayment the user buys on your site. In ExpressPayFlow the user is
    direct to PayPal to confirm their purchase. PayPalPro implements both
    flows. To it create an instance using the these parameters:

    item: a dictionary that holds information about the item being purchased.

    For single item purchase (pay once):

        Required Keys:
            * amt: Float amount of the item.

        Optional Keys:
            * custom: You can set this to help you identify a transaction.
            * invnum: Unique ID that identifies this transaction.

    For recurring billing:

        Required Keys:
          * amt: Float amount for each billing cycle.
          * billingperiod: String unit of measure for the billing cycle (Day|Week|SemiMonth|Month|Year)
          * billingfrequency: Integer number of periods that make up a cycle.
          * profilestartdate: The date to begin billing. "2008-08-05T17:00:00Z" UTC/GMT
          * desc: Description of what you're billing for.

        Optional Keys:
          * trialbillingperiod: String unit of measure for trial cycle (Day|Week|SemiMonth|Month|Year)
          * trialbillingfrequency: Integer # of periods in a cycle.
          * trialamt: Float amount to bill for the trial period.
          * trialtotalbillingcycles: Integer # of cycles for the trial payment period.
          * failedinitamtaction: set to continue on failure (ContinueOnFailure / CancelOnFailure)
          * maxfailedpayments: number of payments before profile is suspended.
          * autobilloutamt: automatically bill outstanding amount.
          * subscribername: Full name of the person who paid.
          * profilereference: Unique reference or invoice number.
          * taxamt: How much tax.
          * initamt: Initial non-recurring payment due upon creation.
          * currencycode: defaults to USD
          * + a bunch of shipping fields

    payment_form_cls: form class that will be used to display the payment form.
    It should inherit from `paypal.pro.forms.PaymentForm` if you're adding more.

    payment_template: template used to ask the dude for monies. To comply with
    PayPal standards it must include a link to PayPal Express Checkout.

    confirm_form_cls: form class that will be used to display the confirmation form.
    It should inherit from `paypal.pro.forms.ConfirmForm`. It is only used in the Express flow.

    success_url / fail_url: URLs to be redirected to when the payment successful or fails.
    """
    errors = {
        "processing": "There was an error processing your payment. Check your information and try again.",
        "form": "Please correct the errors below and try again.",
        "paypal": "There was a problem contacting PayPal. Please try again later."
    }

    def __init__(self, item=None, payment_form_cls=PaymentForm,
                 payment_template="pro/payment.html", confirm_form_cls=ConfirmForm,
                 confirm_template="pro/confirm.html", success_url="?success",
                 fail_url=None, context=None, form_context_name="form", nvp_handler=None):
        self.item = item
        self.payment_form_cls = payment_form_cls
        self.payment_template = payment_template
        self.confirm_form_cls = confirm_form_cls
        self.confirm_template = confirm_template
        self.success_url = success_url
        self.fail_url = fail_url
        self.context = context or {}
        self.form_context_name = form_context_name
        self.nvp_handler = nvp_handler

        if nvp_handler is None:
            warnings.warn(
                "You didn't pass `nvp_handler` to PayPalPro. You should pass a callback "
                "here instead of using the `payment_was_successful` "
                "signal", DeprecationWarning)

    def __call__(self, request):
        """Return the appropriate response for the state of the transaction."""
        self.request = request
        if request.method == "GET":
            if self.should_redirect_to_express():
                return self.redirect_to_express()
            elif self.should_render_confirm_form():
                return self.render_confirm_form()
            elif self.should_render_payment_form():
                return self.render_payment_form()
        else:
            if self.should_validate_confirm_form():
                return self.validate_confirm_form()
            elif self.should_validate_payment_form():
                return self.validate_payment_form()

        # Default to the rendering the payment form.
        return self.render_payment_form()

    def is_recurring(self):
        return self.item is not None and 'billingperiod' in self.item

    def should_redirect_to_express(self):
        return 'express' in self.request.GET

    def should_render_confirm_form(self):
        return 'token' in self.request.GET and 'PayerID' in self.request.GET

    def should_render_payment_form(self):
        return True

    def should_validate_confirm_form(self):
        return 'token' in self.request.POST and 'PayerID' in self.request.POST

    def should_validate_payment_form(self):
        return True

    def render_payment_form(self):
        """Display the DirectPayment for entering payment information."""
        self.context[self.form_context_name] = self.payment_form_cls()
        return TemplateResponse(self.request, self.payment_template, self.context)

    def validate_payment_form(self):
        """Try to validate and then process the DirectPayment form."""
        warn_untested()
        form = self.payment_form_cls(self.request.POST)
        if form.is_valid():
            success = form.process(self.request, self.item)
            if success:
                return HttpResponseRedirect(self.success_url)
            else:
                self.context['errors'] = self.errors['processing']

        self.context[self.form_context_name] = form
        self.context.setdefault("errors", self.errors['form'])
        return TemplateResponse(self.request, self.payment_template, self.context)

    def redirect_to_express(self):
        """
        First step of ExpressCheckout. Redirect the request to PayPal using the
        data returned from setExpressCheckout.
        """
        wpp = PayPalWPP(self.request)
        try:
            nvp_obj = wpp.setExpressCheckout(self.item)
        except PayPalFailure:
            warn_untested()
            self.context['errors'] = self.errors['paypal']
            return self.render_payment_form()
        else:
            return HttpResponseRedirect(express_endpoint_for_token(nvp_obj.token))

    def render_confirm_form(self):
        """
        Second step of ExpressCheckout. Display an order confirmation form which
        contains hidden fields with the token / PayerID from PayPal.
        """
        warn_untested()
        initial = dict(token=self.request.GET['token'], PayerID=self.request.GET['PayerID'])
        self.context[self.form_context_name] = self.confirm_form_cls(initial=initial)
        return TemplateResponse(self.request, self.confirm_template, self.context)

    def validate_confirm_form(self):
        """
        Third and final step of ExpressCheckout. Request has pressed the confirmation but
        and we can send the final confirmation to PayPal using the data from the POST'ed form.
        """
        wpp = PayPalWPP(self.request)
        pp_data = dict(token=self.request.POST['token'], payerid=self.request.POST['PayerID'])
        self.item.update(pp_data)

        # @@@ This check and call could be moved into PayPalWPP.
        try:
            if self.is_recurring():
                warn_untested()
                nvp = wpp.createRecurringPaymentsProfile(self.item)
            else:
                nvp = wpp.doExpressCheckoutPayment(self.item)
            self.handle_nvp(nvp)
        except PayPalFailure:
            self.context['errors'] = self.errors['processing']
            return self.render_payment_form()
        else:
            return HttpResponseRedirect(self.success_url)

    def handle_nvp(self, nvp):
        if self.nvp_handler is not None:
            self.nvp_handler(nvp)
