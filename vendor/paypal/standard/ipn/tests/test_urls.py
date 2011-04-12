from django.conf.urls.defaults import *

urlpatterns = patterns('paypal.standard.ipn.views',
    (r'^ipn/$', 'ipn'),
)
