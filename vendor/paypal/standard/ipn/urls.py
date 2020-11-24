from __future__ import unicode_literals

from django.conf.urls import url

from paypal.standard.ipn import views

urlpatterns = [
    url(r'^$', views.ipn, name="paypal-ipn"),
]
