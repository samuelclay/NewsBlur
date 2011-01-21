from django.conf.urls.defaults import *
from apps.api import views

urlpatterns = patterns('',
    url(r'^add_site/(?P<token>\w+)', views.add_site, name='api-add-site'),
)
