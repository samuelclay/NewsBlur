#!/usr/bin/env python
# -*- coding: utf-8 -*-
from string import split as L
from django.contrib import admin
from paypal.pro.models import PayPalNVP


class PayPalNVPAdmin(admin.ModelAdmin):
    list_display = L("user method flag flag_code created_at")
admin.site.register(PayPalNVP, PayPalNVPAdmin)
