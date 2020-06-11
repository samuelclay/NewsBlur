from django.conf.urls import url
from paypal.standard.pdt.views import pdt
urlpatterns = [
    url(r'^$', pdt, name="paypal-pdt"),
]
