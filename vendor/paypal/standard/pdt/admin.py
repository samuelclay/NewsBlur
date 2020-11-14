#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.contrib import admin

from paypal.standard.pdt.models import PayPalPDT


# ToDo: How similiar is this to PayPalIPNAdmin? Could we just inherit off one common admin model?
class PayPalPDTAdmin(admin.ModelAdmin):
    date_hierarchy = 'payment_date'
    fieldsets = (
        (None, {
            "fields":
                ['flag',
                 'txn_id',
                 'txn_type',
                 'payment_status',
                 'payment_date',
                 'transaction_entity',
                 'reason_code',
                 'pending_reason',
                 'mc_gross',
                 'mc_fee',
                 'auth_status',
                 'auth_amount',
                 'auth_exp',
                 'auth_id',
                 ],
        }),
        ("Address", {
            "description": "The address of the Buyer.",
            'classes': ('collapse',),
            "fields":
                ['address_city',
                 'address_country',
                 'address_country_code',
                 'address_name',
                 'address_state',
                 'address_status',
                 'address_street',
                 'address_zip',
                 ],
        }),
        ("Buyer", {
            "description": "The information about the Buyer.",
            'classes': ('collapse',),
            "fields":
                ['first_name',
                 'last_name',
                 'payer_business_name',
                 'payer_email',
                 'payer_id',
                 'payer_status',
                 'contact_phone',
                 'residence_country'
                 ],
        }),
        ("Seller", {
            "description": "The information about the Seller.",
            'classes': ('collapse',),
            "fields":
                ['business',
                 'item_name',
                 'item_number',
                 'quantity',
                 'receiver_email',
                 'receiver_id',
                 'custom',
                 'invoice',
                 'memo',
                 ],
        }),
        ("Subscriber", {
            "description": "The information about the Subscription.",
            'classes': ('collapse',),
            "fields":
                ['subscr_id',
                 'subscr_date',
                 'subscr_effective',
                 ],
        }),
        ("Recurring", {
            "description": "Information about recurring Payments.",
            "classes": ("collapse",),
            "fields":
                ['profile_status',
                 'initial_payment_amount',
                 'amount_per_cycle',
                 'outstanding_balance',
                 'period_type',
                 'product_name',
                 'product_type',
                 'recurring_payment_id',
                 'receipt_id',
                 'next_payment_date',
                 ],
        }),
        ("Admin", {
            "description": "Additional Info.",
            "classes": ('collapse',),
            "fields":
                ['test_ipn',
                 'ipaddress',
                 'query',
                 'flag_code',
                 'flag_info',
                 ],
        }),
    )
    list_display = ["__unicode__",
                    "flag",
                    "invoice",
                    "custom",
                    "payment_status",
                    "created_at",
                    ]
    search_fields = ["txn_id",
                     "recurring_payment_id",
                     ]


admin.site.register(PayPalPDT, PayPalPDTAdmin)
