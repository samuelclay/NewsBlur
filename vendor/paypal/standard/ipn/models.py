#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from six import b
from six.moves.urllib.request import urlopen

from paypal.standard.models import PayPalStandardBase
from paypal.standard.ipn.signals import payment_was_flagged, payment_was_refunded, payment_was_reversed, payment_was_successful, recurring_create, recurring_payment, recurring_cancel, recurring_skipped, recurring_failed, subscription_cancel, subscription_signup, subscription_eot, subscription_modify


class PayPalIPN(PayPalStandardBase):
    """Logs PayPal IPN interactions."""
    format = u"<IPN: %s %s>"

    class Meta:
        db_table = "paypal_ipn"
        verbose_name = "PayPal IPN"

    def _postback(self):
        """Perform PayPal Postback validation."""
        return urlopen(self.get_endpoint(), b("cmd=_notify-validate&%s" % self.query)).read()

    def _verify_postback(self):
        if self.response != "VERIFIED":
            self.set_flag("Invalid postback. ({0})".format(self.response))

    def send_signals(self):
        """Shout for the world to hear whether a txn was successful."""
        if self.flag:
            payment_was_flagged.send(sender=self)
            return

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
                recurring_payment.send(sender=self)
            elif self.is_recurring_cancel():
                recurring_cancel.send(sender=self)
            elif self.is_recurring_skipped():
                recurring_skipped.send(sender=self)
            elif self.is_recurring_failed():
                recurring_failed.send(sender=self)
       # Subscription signals:
        else:
            if self.is_subscription_cancellation():
                subscription_cancel.send(sender=self)
            elif self.is_subscription_signup():
                subscription_signup.send(sender=self)
            elif self.is_subscription_end_of_term():
                subscription_eot.send(sender=self)
            elif self.is_subscription_modified():
                subscription_modify.send(sender=self)
