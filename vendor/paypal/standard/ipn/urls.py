from django.conf.urls import url
from paypal.standard.ipn.views import ipn

urlpatterns = [
    url(r'^$', ipn, name="paypal-ipn"),
]
