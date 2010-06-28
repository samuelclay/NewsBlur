from django.conf.urls.defaults import *
from apps.opml_import import views

urlpatterns = patterns('apps.opml_import.views',
    url(r'^opml_upload$', views.opml_upload),
    url(r'^authorize/$', views.reader_authorize, name='opml-reader-authorize'),
    url(r'^callback/$', views.reader_callback, name='opml-reader-callback')
)
