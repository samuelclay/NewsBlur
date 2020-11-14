#!/usr/bin/env python
# -*- coding: utf-8 -*-
from django.contrib import admin, messages

from paypal.standard.ipn.models import PayPalIPN


def reverify_flagged(modeladmin, request, queryset):
    q = queryset.filter(flag=True)
    for ipn in q:
        ipn.verify()
        ipn.send_signals()
    messages.info(request, "{0} IPN object(s) re-verified".format(len(q)))
reverify_flagged.short_description = "Re-verify selected flagged IPNs"


class PayPalIPNAdmin(admin.ModelAdmin):
    list_filter = [
        'payment_status',
        'flag',
        'txn_type',
    ]
    date_hierarchy = 'payment_date'
    fieldsets = (
        (None, {
            "fields": [
                "flag", "txn_id", "txn_type", "payment_status", "payment_date",
                "transaction_entity", "reason_code", "pending_reason",
                "mc_currency", "mc_gross", "mc_fee", "mc_handling", "mc_shipping",
                "auth_status", "auth_amount", "auth_exp", "auth_id"
            ]
        }),
        ("Address", {
            "description": "The address of the Buyer.",
            'classes': ('collapse',),
            "fields": [
                "address_city", "address_country", "address_country_code",
                "address_name", "address_state", "address_status",
                "address_street", "address_zip"
            ]
        }),
        ("Buyer", {
            "description": "The information about the Buyer.",
            'classes': ('collapse',),
            "fields": [
                "first_name", "last_name", "payer_business_name", "payer_email",
                "payer_id", "payer_status", "contact_phone", "residence_country"
            ]
        }),
        ("Seller", {
            "description": "The information about the Seller.",
            'classes': ('collapse',),
            "fields": [
                "business", "item_name", "item_number", "quantity",
                "receiver_email", "receiver_id", "custom", "invoice", "memo"
            ]
        }),
        ("Recurring", {
            "description": "Information about recurring Payments.",
            "classes": ("collapse",),
            "fields": [
                "profile_status", "initial_payment_amount", "amount_per_cycle",
                "outstanding_balance", "period_type", "product_name",
                "product_type", "recurring_payment_id", "receipt_id",
                "next_payment_date"
            ]
        }),
        ("Subscription", {
            "description": "Information about recurring Subscptions.",
            "classes": ("collapse",),
            "fields": [
                "subscr_date", "subscr_effective", "period1", "period2",
                "period3", "amount1", "amount2", "amount3", "mc_amount1",
                "mc_amount2", "mc_amount3", "recurring", "reattempt",
                "retry_at", "recur_times", "username", "password", "subscr_id"
            ]
        }),
        ("Admin", {
            "description": "Additional Info.",
            "classes": ('collapse',),
            "fields": [
                "test_ipn", "ipaddress", "query", "response", "flag_code",
                "flag_info"
            ]
        }),
    )
    list_display = [
        "__unicode__", "flag", "flag_info", "invoice", "custom",
        "payment_status", "created_at"
    ]
    search_fields = ["txn_id", "recurring_payment_id", "subscr_id"]

    actions = [reverify_flagged]

admin.site.register(PayPalIPN, PayPalIPNAdmin)
