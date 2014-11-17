from django.conf.urls import patterns

urlpatterns = patterns('paypal.standard.pdt.views',
                       (r'^pdt/$', 'pdt'),
)
