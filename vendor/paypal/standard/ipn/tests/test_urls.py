from django.conf.urls import *

urlpatterns = patterns('paypal.standard.ipn.views',
    (r'^ipn/$', 'ipn'),
)
