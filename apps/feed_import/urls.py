from django.conf.urls.defaults import *
from apps.feed_import import views

urlpatterns = patterns('apps.feed_import.views',
    url(r'^opml_upload$', views.opml_upload, name='opml-upload'),
    url(r'^authorize/$', views.reader_authorize, name='google-reader-authorize'),
    url(r'^callback/$', views.reader_callback, name='google-reader-callback'),
    url(r'^signup/$', views.import_signup, name='import-signup'),
    url(r'^import_from_google_reader/$', views.import_from_google_reader, name='import-from-google-reader')
)
