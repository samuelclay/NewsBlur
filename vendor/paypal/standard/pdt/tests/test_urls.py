from django.conf.urls import *

urlpatterns = patterns('paypal.standard.pdt.views',
    (r'^pdt/$', 'pdt'),
)
