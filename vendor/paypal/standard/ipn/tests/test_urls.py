from __future__ import unicode_literals

import django
from django.conf.urls import url
from django.contrib import admin

from paypal.standard.ipn import views

if django.VERSION < (1, 7):
    import paypal.standard.ipn.admin  # noqa
    admin.autodiscover()


urlpatterns = [
    url(r'^ipn/$', views.ipn),
    url(r'^admin/', admin.site.urls),
]


if django.VERSION < (1, 8):
    from django.conf.urls import patterns
    urlpatterns = patterns('', *urlpatterns)
