from django.conf.urls.defaults import *

urlpatterns = patterns('paypal.standard.pdt.views',
    (r'^pdt/$', 'pdt'),
)
