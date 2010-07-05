from django.conf.urls.defaults import *
from apps.feed_import import views

urlpatterns = patterns('apps.feed_import.views',
    url(r'^opml_upload$', views.opml_upload, name='opml-upload'),
    url(r'^authorize/$', views.reader_authorize, name='opml-reader-authorize'),
    url(r'^callback/$', views.reader_callback, name='opml-reader-callback'),
    url(r'^signup/$', views.import_signup, name='import-signup')
)
