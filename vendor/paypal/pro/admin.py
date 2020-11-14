#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.contrib import admin

from paypal.pro.models import PayPalNVP


class PayPalNVPAdmin(admin.ModelAdmin):
    list_display = ('user', 'ipaddress', 'method', 'flag', 'flag_code', 'created_at')
    list_filter = ('flag', 'created_at')
    search_fields = ('user__email', 'ipaddress', 'flag', 'firstname', 'lastname')


admin.site.register(PayPalNVP, PayPalNVPAdmin)
