from django.conf.urls import patterns, url

urlpatterns = patterns('paypal.standard.pdt.views',
                       url(r'^$', 'pdt', name="paypal-pdt"),
)
