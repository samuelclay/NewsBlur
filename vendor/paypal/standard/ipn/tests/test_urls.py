from django.conf.urls import url

urlpatterns = [
    url('paypal.standard.ipn.views', (r'^ipn/$', 'ipn'),
]
