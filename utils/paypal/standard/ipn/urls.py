from django.conf.urls.defaults import *

urlpatterns = patterns('paypal.standard.ipn.views',            
    url(r'^$', 'ipn', name="paypal-ipn"),
)