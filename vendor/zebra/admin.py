from django.contrib import admin

from zebra.conf import options

if options.ZEBRA_ENABLE_APP:
    from vendor.zebra.models import Customer, Plan, Subscription
    
    admin.site.register(Customer)
    admin.site.register(Plan)
    admin.site.register(Subscription)
