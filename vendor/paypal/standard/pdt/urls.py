from django.conf.urls import *

urlpatterns = patterns('paypal.standard.pdt.views',
    url(r'^$', 'pdt', name="paypal-pdt"),
)