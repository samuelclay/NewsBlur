#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import unicode_literals

import requests

from paypal.standard.ipn.signals import (
    invalid_ipn_received, payment_was_flagged, payment_was_refunded, payment_was_reversed, payment_was_successful,
    recurring_cancel, recurring_create, recurring_failed, recurring_payment, recurring_skipped, subscription_cancel,
    subscription_eot, subscription_modify, subscription_signup, valid_ipn_received
)
from paypal.standard.models import PayPalStandardBase
from paypal.utils import warn_untested


class PayPalIPN(PayPalStandardBase):
    """Logs PayPal IPN interactions."""
    format = u"<IPN: %s %s>"

    class Meta:
        db_table = "paypal_ipn"
        verbose_name = "PayPal IPN"

    def _postback(self):
        """Perform PayPal Postback validation."""
        return requests.post(self.get_endpoint(), data=b"cmd=_notify-validate&" + self.query.encode("ascii")).content

    def _verify_postback(self):
        if self.response != "VERIFIED":
            self.set_flag("Invalid postback. ({0})".format(self.response))

    def send_signals(self):
        """Shout for the world to hear whether a txn was successful."""
        if self.flag:
            invalid_ipn_received.send(sender=self)
            payment_was_flagged.send(sender=self)
            return
        else:
            valid_ipn_received.send(sender=self)

        # Transaction signals:
        if self.is_transaction():
            if self.is_refund():
                payment_was_refunded.send(sender=self)
            elif self.is_reversed():
                payment_was_reversed.send(sender=self)
            else:
                payment_was_successful.send(sender=self)
        # Recurring payment signals:
        # XXX: Should these be merged with subscriptions?
        elif self.is_recurring():
            if self.is_recurring_create():
                recurring_create.send(sender=self)
            elif self.is_recurring_payment():
                warn_untested()
                recurring_payment.send(sender=self)
            elif self.is_recurring_cancel():
                recurring_cancel.send(sender=self)
            elif self.is_recurring_skipped():
                recurring_skipped.send(sender=self)
            elif self.is_recurring_failed():
                recurring_failed.send(sender=self)
        # Subscription signals:
        else:
            warn_untested()
            if self.is_subscription_cancellation():
                subscription_cancel.send(sender=self)
            elif self.is_subscription_signup():
                subscription_signup.send(sender=self)
            elif self.is_subscription_end_of_term():
                subscription_eot.send(sender=self)
            elif self.is_subscription_modified():
                subscription_modify.send(sender=self)

    def __repr__(self):
        return '<PayPalIPN id:{0}>'.format(self.id)

    def __str__(self):
        return "PayPalIPN: {0}".format(self.id)
