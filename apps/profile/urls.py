from django.conf.urls.defaults import *
from apps.profile import views

urlpatterns = patterns('',
    (r'^get_preference/?', views.get_preference),
    (r'^set_preference/?', views.set_preference),
    (r'^get_view_setting/?', views.get_view_setting),
    (r'^set_view_setting/?', views.set_view_setting),
    (r'^set_collapsed_folders/?', views.set_collapsed_folders),
    (r'^paypal_form/?', views.paypal_form),
    (r'^paypal_ipn/?', include('paypal.standard.ipn.urls')),
)
