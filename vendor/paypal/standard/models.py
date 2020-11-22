#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from warnings import warn

from django.conf import settings
from django.db import models
from django.utils.functional import cached_property

from paypal.standard.conf import POSTBACK_ENDPOINT, SANDBOX_POSTBACK_ENDPOINT
from paypal.standard.helpers import check_secret, duplicate_txn_id
from paypal.utils import warn_untested

ST_PP_ACTIVE = 'Active'
ST_PP_CANCELLED = 'Cancelled'
ST_PP_CANCELED_REVERSAL = 'Canceled_Reversal'
ST_PP_CLEARED = 'Cleared'
ST_PP_COMPLETED = 'Completed'
ST_PP_CREATED = 'Created'
ST_PP_DECLINED = 'Declined'
ST_PP_DENIED = 'Denied'
ST_PP_EXPIRED = 'Expired'
ST_PP_FAILED = 'Failed'
ST_PP_PAID = 'Paid'
ST_PP_PENDING = 'Pending'
ST_PP_PROCESSED = 'Processed'
ST_PP_REFUNDED = 'Refunded'
ST_PP_REFUSED = 'Refused'
ST_PP_REVERSED = 'Reversed'
ST_PP_REWARDED = 'Rewarded'
ST_PP_UNCLAIMED = 'Unclaimed'
ST_PP_UNCLEARED = 'Uncleared'
ST_PP_VOIDED = 'Voided'

try:
    from idmapper.models import SharedMemoryModel as Model
except ImportError:
    Model = models.Model


DEFAULT_ENCODING = 'windows-1252'  # PayPal seems to normally use this.


class PayPalStandardBase(Model):
    """Base class for common variables shared by IPN and PDT"""
    # See https://developer.paypal.com/docs/classic/ipn/integration-guide/IPNandPDTVariables/

    # @@@ Might want to add all these one distant day.
    # FLAG_CODE_CHOICES = (
    # PAYMENT_STATUS_CHOICES = "Canceled_ Reversal Completed Denied Expired " \
    #                          "Failed Pending Processed Refunded Reversed Voided".split()
    PAYMENT_STATUS_CHOICES = [ST_PP_ACTIVE,
                              ST_PP_CANCELLED,
                              ST_PP_CANCELED_REVERSAL,
                              ST_PP_CLEARED,
                              ST_PP_COMPLETED,
                              ST_PP_CREATED,
                              ST_PP_DECLINED,
                              ST_PP_DENIED,
                              ST_PP_EXPIRED,
                              ST_PP_FAILED,
                              ST_PP_PAID,
                              ST_PP_PENDING,
                              ST_PP_PROCESSED,
                              ST_PP_REFUNDED,
                              ST_PP_REFUSED,
                              ST_PP_REVERSED,
                              ST_PP_REWARDED,
                              ST_PP_UNCLAIMED,
                              ST_PP_UNCLEARED,
                              ST_PP_VOIDED,
                              ]
    # AUTH_STATUS_CHOICES = "Completed Pending Voided".split()
    # ADDRESS_STATUS_CHOICES = "confirmed unconfirmed".split()
    # PAYER_STATUS_CHOICES = "verified / unverified".split()
    # PAYMENT_TYPE_CHOICES =  "echeck / instant.split()
    # PENDING_REASON = "address authorization echeck intl multi-currency unilateral upgrade verify other".split()
    # REASON_CODE = "chargeback guarantee buyer_complaint refund other".split()
    # TRANSACTION_ENTITY_CHOICES = "auth reauth order payment".split()

    # Transaction and Notification-Related Variables
    business = models.CharField(max_length=127, blank=True, help_text="Email where the money was sent.")
    charset = models.CharField(max_length=255, blank=True)
    custom = models.CharField(max_length=256, blank=True)
    notify_version = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    parent_txn_id = models.CharField("Parent Transaction ID", max_length=19, blank=True)
    receiver_email = models.EmailField(max_length=254, blank=True)
    receiver_id = models.CharField(max_length=255, blank=True)  # 258DLEHY2BDK6
    residence_country = models.CharField(max_length=2, blank=True)
    test_ipn = models.BooleanField(default=False, blank=True)
    txn_id = models.CharField("Transaction ID", max_length=255, blank=True, help_text="PayPal transaction ID.",
                              db_index=True)
    txn_type = models.CharField("Transaction Type", max_length=255, blank=True, help_text="PayPal transaction type.")
    verify_sign = models.CharField(max_length=255, blank=True)

    # Buyer Information Variables
    address_country = models.CharField(max_length=64, blank=True)
    address_city = models.CharField(max_length=40, blank=True)
    address_country_code = models.CharField(max_length=64, blank=True, help_text="ISO 3166")
    address_name = models.CharField(max_length=128, blank=True)
    address_state = models.CharField(max_length=40, blank=True)
    address_status = models.CharField(max_length=255, blank=True)
    address_street = models.CharField(max_length=200, blank=True)
    address_zip = models.CharField(max_length=20, blank=True)
    contact_phone = models.CharField(max_length=20, blank=True)
    first_name = models.CharField(max_length=64, blank=True)
    last_name = models.CharField(max_length=64, blank=True)
    payer_business_name = models.CharField(max_length=127, blank=True)
    payer_email = models.CharField(max_length=127, blank=True)
    payer_id = models.CharField(max_length=13, blank=True)

    # Payment Information Variables
    auth_amount = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    auth_exp = models.CharField(max_length=28, blank=True)
    auth_id = models.CharField(max_length=19, blank=True)
    auth_status = models.CharField(max_length=255, blank=True)
    exchange_rate = models.DecimalField(max_digits=64, decimal_places=16, default=0, blank=True, null=True)
    invoice = models.CharField(max_length=127, blank=True)
    item_name = models.CharField(max_length=127, blank=True)
    item_number = models.CharField(max_length=127, blank=True)
    mc_currency = models.CharField(max_length=32, default="USD", blank=True)
    mc_fee = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    mc_gross = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    mc_handling = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    mc_shipping = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    memo = models.CharField(max_length=255, blank=True)
    num_cart_items = models.IntegerField(blank=True, default=0, null=True)
    option_name1 = models.CharField(max_length=64, blank=True)
    option_name2 = models.CharField(max_length=64, blank=True)
    option_selection1 = models.CharField(max_length=200, blank=True)
    option_selection2 = models.CharField(max_length=200, blank=True)
    payer_status = models.CharField(max_length=255, blank=True)
    payment_date = models.DateTimeField(blank=True, null=True, help_text="HH:MM:SS DD Mmm YY, YYYY PST")
    payment_gross = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    payment_status = models.CharField(max_length=255, blank=True)
    payment_type = models.CharField(max_length=255, blank=True)
    pending_reason = models.CharField(max_length=255, blank=True)
    protection_eligibility = models.CharField(max_length=255, blank=True)
    quantity = models.IntegerField(blank=True, default=1, null=True)
    reason_code = models.CharField(max_length=255, blank=True)
    remaining_settle = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    settle_amount = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    settle_currency = models.CharField(max_length=32, blank=True)
    shipping = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    shipping_method = models.CharField(max_length=255, blank=True)
    tax = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    transaction_entity = models.CharField(max_length=255, blank=True)

    # Auction Variables
    auction_buyer_id = models.CharField(max_length=64, blank=True)
    auction_closing_date = models.DateTimeField(blank=True, null=True, help_text="HH:MM:SS DD Mmm YY, YYYY PST")
    auction_multi_item = models.IntegerField(blank=True, default=0, null=True)
    for_auction = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)

    # Recurring Payments Variables
    amount = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    amount_per_cycle = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    initial_payment_amount = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    next_payment_date = models.DateTimeField(blank=True, null=True, help_text="HH:MM:SS DD Mmm YY, YYYY PST")
    outstanding_balance = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    payment_cycle = models.CharField(max_length=255, blank=True)  # Monthly
    period_type = models.CharField(max_length=255, blank=True)
    product_name = models.CharField(max_length=255, blank=True)
    product_type = models.CharField(max_length=255, blank=True)
    profile_status = models.CharField(max_length=255, blank=True)
    recurring_payment_id = models.CharField(max_length=255, blank=True)  # I-FA4XVST722B9
    rp_invoice_id = models.CharField(max_length=127, blank=True)  # 1335-7816-2936-1451
    time_created = models.DateTimeField(blank=True, null=True, help_text="HH:MM:SS DD Mmm YY, YYYY PST")

    # Subscription Variables
    amount1 = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    amount2 = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    amount3 = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    mc_amount1 = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    mc_amount2 = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    mc_amount3 = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    password = models.CharField(max_length=24, blank=True)
    period1 = models.CharField(max_length=255, blank=True)
    period2 = models.CharField(max_length=255, blank=True)
    period3 = models.CharField(max_length=255, blank=True)
    reattempt = models.CharField(max_length=1, blank=True)
    recur_times = models.IntegerField(blank=True, default=0, null=True)
    recurring = models.CharField(max_length=1, blank=True)
    retry_at = models.DateTimeField(blank=True, null=True, help_text="HH:MM:SS DD Mmm YY, YYYY PST")
    subscr_date = models.DateTimeField(blank=True, null=True, help_text="HH:MM:SS DD Mmm YY, YYYY PST")
    subscr_effective = models.DateTimeField(blank=True, null=True, help_text="HH:MM:SS DD Mmm YY, YYYY PST")
    subscr_id = models.CharField(max_length=19, blank=True)
    username = models.CharField(max_length=64, blank=True)

    # Billing Agreement Variables
    mp_id = models.CharField(max_length=128, blank=True, null=True)  # B-0G433009BJ555711U

    # Dispute Resolution Variables
    case_creation_date = models.DateTimeField(blank=True, null=True, help_text="HH:MM:SS DD Mmm YY, YYYY PST")
    case_id = models.CharField(max_length=255, blank=True)
    case_type = models.CharField(max_length=255, blank=True)

    # Variables not categorized
    receipt_id = models.CharField(max_length=255, blank=True)  # 1335-7816-2936-1451
    currency_code = models.CharField(max_length=32, default="USD", blank=True)
    handling_amount = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)

    # This undocumented variable apparently contains the same as the 'custom'
    # field - http://stackoverflow.com/questions/8464442/set-transaction-subject-paypal-ipn
    transaction_subject = models.CharField(max_length=256, blank=True)

    # @@@ Mass Pay Variables (Not Implemented, needs a separate model, for each transaction x)
    # fraud_managment_pending_filters_x = models.CharField(max_length=255, blank=True)
    # option_selection1_x = models.CharField(max_length=200, blank=True)
    # option_selection2_x = models.CharField(max_length=200, blank=True)
    # masspay_txn_id_x = models.CharField(max_length=19, blank=True)
    # mc_currency_x = models.CharField(max_length=32, default="USD", blank=True)
    # mc_fee_x = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    # mc_gross_x = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    # mc_handlingx = models.DecimalField(max_digits=64, decimal_places=2, default=0, blank=True, null=True)
    # payment_date = models.DateTimeField(blank=True, null=True, help_text="HH:MM:SS DD Mmm YY, YYYY PST")
    # payment_status = models.CharField(max_length=9, blank=True)
    # reason_code = models.CharField(max_length=15, blank=True)
    # receiver_email_x = models.EmailField(max_length=127, blank=True)
    # status_x = models.CharField(max_length=9, blank=True)
    # unique_id_x = models.CharField(max_length=13, blank=True)

    # Non-PayPal Variables - full IPN/PDT query and time fields.
    ipaddress = models.GenericIPAddressField(blank=True, null=True)
    flag = models.BooleanField(default=False, blank=True)
    flag_code = models.CharField(max_length=16, blank=True)
    flag_info = models.TextField(blank=True)
    query = models.TextField(blank=True)  # What Paypal sent to us initially
    response = models.TextField(blank=True)  # What we got back from our request
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # Where did it come from?
    from_view = models.CharField(max_length=6, null=True, blank=True)

    class Meta:
        abstract = True
        app_label = 'paypal_standard_base'  # Keep Django 1.7 quiet

    def __unicode__(self):
        if self.is_transaction():
            return self.format % ("Transaction", self.txn_id)
        elif self.is_subscription():
            return self.format % ("Subscription", self.subscr_id)
        else:
            return self.format % ("Recurring", self.recurring_payment_id)

    @cached_property
    def posted_data_dict(self):
        """
        All the data that PayPal posted to us, as a correctly parsed dictionary of values.
        """
        if not self.query:
            return None
        from django.http import QueryDict
        roughdecode = dict(item.split('=', 1) for item in self.query.split('&'))
        encoding = roughdecode.get('charset', None)
        if encoding is None:
            encoding = DEFAULT_ENCODING
        query = self.query.encode('ascii')
        data = QueryDict(query, encoding=encoding)
        return data.dict()

    def is_transaction(self):
        return len(self.txn_id) > 0

    def is_refund(self):
        return self.payment_status == ST_PP_REFUNDED

    def is_reversed(self):
        return self.payment_status == ST_PP_REVERSED

    def is_recurring(self):
        return len(self.recurring_payment_id) > 0

    def is_subscription(self):
        warn_untested()
        return len(self.subscr_id) > 0

    def is_subscription_payment(self):
        warn_untested()
        return self.txn_type == "subscr_payment"

    def is_subscription_failed(self):
        warn_untested()
        return self.txn_type == "subscr_failed"

    def is_subscription_cancellation(self):
        warn_untested()
        return self.txn_type == "subscr_cancel"

    def is_subscription_end_of_term(self):
        warn_untested()
        return self.txn_type == "subscr_eot"

    def is_subscription_modified(self):
        warn_untested()
        return self.txn_type == "subscr_modify"

    def is_subscription_signup(self):
        warn_untested()
        return self.txn_type == "subscr_signup"

    def is_recurring_create(self):
        return self.txn_type == "recurring_payment_profile_created"

    def is_recurring_payment(self):
        return self.txn_type == "recurring_payment"

    def is_recurring_cancel(self):
        return self.txn_type == "recurring_payment_profile_cancel"

    def is_recurring_skipped(self):
        return self.txn_type == "recurring_payment_skipped"

    def is_recurring_failed(self):
        return self.txn_type == "recurring_payment_failed"

    def is_recurring_suspended(self):
        warn_untested()
        return self.txn_type == "recurring_payment_suspended"

    def is_recurring_suspended_due_to_max_failed_payment(self):
        warn_untested()
        return self.txn_type == "recurring_payment_suspended_due_to_max_failed_payment"

    def is_billing_agreement(self):
        warn_untested()
        return len(self.mp_id) > 0

    def is_billing_agreement_create(self):
        warn_untested()
        return self.txn_type == "mp_signup"

    def is_billing_agreement_cancel(self):
        warn_untested()
        return self.txn_type == "mp_cancel"

    def set_flag(self, info, code=None):
        """Sets a flag on the transaction and also sets a reason."""
        self.flag = True
        self.flag_info += info
        if code is not None:
            warn_untested()
            self.flag_code = code

    def clear_flag(self):
        self.flag = False
        self.flag_info = ""
        self.flag_code = ""

    def verify(self):
        """
        Verifies an IPN and a PDT.
        Checks for obvious signs of weirdness in the payment and flags appropriately.
        """
        self.response = self._postback().decode('ascii')
        self.clear_flag()
        self._verify_postback()
        if not self.flag:
            if self.is_transaction():
                if self.payment_status not in self.PAYMENT_STATUS_CHOICES:
                    self.set_flag("Invalid payment_status. (%s)" % self.payment_status)
                if duplicate_txn_id(self):
                    self.set_flag("Duplicate txn_id. (%s)" % self.txn_id)
                if hasattr(settings, 'PAYPAL_RECEIVER_EMAIL'):
                    warn("Use of PAYPAL_RECEIVER_EMAIL in settings has been Deprecated.\n"
                         "Check of valid email must be done when receiving the\n"
                         "valid_ipn_received signal",
                         DeprecationWarning)
                    if self.receiver_email != settings.PAYPAL_RECEIVER_EMAIL:
                        self.set_flag("Invalid receiver_email. (%s)" % self.receiver_email)
            else:
                # @@@ Run a different series of checks on recurring payments.
                pass

        self.save()

    def verify_secret(self, form_instance, secret):
        """Verifies an IPN payment over SSL using EWP."""
        warn_untested()
        if not check_secret(form_instance, secret):
            self.set_flag("Invalid secret. (%s)") % secret
        self.save()

    def get_endpoint(self):
        """Set Sandbox endpoint if the test variable is present."""
        if self.test_ipn:
            return SANDBOX_POSTBACK_ENDPOINT
        else:
            return POSTBACK_ENDPOINT

    def send_signals(self):
        """Shout for the world to hear whether a txn was successful."""
        raise NotImplementedError

    def initialize(self, request):
        """Store the data we'll need to make the postback from the request object."""
        if request.method == 'GET':
            # PDT only - this data is currently unused
            self.query = request.META.get('QUERY_STRING', '')
        elif request.method == 'POST':
            # The following works if paypal sends an ASCII bytestring, which it does.
            self.query = request.body.decode('ascii')
        self.ipaddress = request.META.get('REMOTE_ADDR', '')

    def _postback(self):
        """Perform postback to PayPal and store the response in self.response."""
        raise NotImplementedError

    def _verify_postback(self):
        """Check self.response is valid andcall self.set_flag if there is an error."""
        raise NotImplementedError
