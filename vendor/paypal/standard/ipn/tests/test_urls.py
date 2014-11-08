from django.conf.urls import patterns

urlpatterns = patterns('paypal.standard.ipn.views',
                       (r'^ipn/$', 'ipn'),
)
