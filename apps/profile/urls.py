from django.conf.urls.defaults import *
from apps.profile import views

urlpatterns = patterns('',
    (r'^get_preference/?', views.get_preference),
    (r'^set_preference/?', views.set_preference),
    (r'^get_view_setting/?', views.get_view_setting),
    (r'^set_view_setting/?', views.set_view_setting),
)
