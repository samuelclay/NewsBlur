from django.conf.urls.defaults import *
from apps.profile import views

urlpatterns = patterns('',
    (r'^get/?', views.get_preference),
    (r'^set/?', views.set_preference),
)
