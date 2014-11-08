from django.conf.urls import patterns, url

urlpatterns = patterns('paypal.standard.ipn.views',
                       url(r'^$', 'ipn', name="paypal-ipn"),
)
