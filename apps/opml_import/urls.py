from django.conf.urls.defaults import *

urlpatterns = patterns('apps.opml_import.views',
    (r'^opml_upload$', 'opml_upload'),
)
