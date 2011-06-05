from django.conf.urls.defaults import *
from apps.mobile import views

urlpatterns = patterns('apps.mobile.views',
    url(r'^$', views.index, name='mobile-index'),
)
