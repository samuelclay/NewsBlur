from django.conf.urls.defaults import *

urlpatterns = patterns('apps.opml_import.views',
    (r'^$', 'opml_import'),
    (r'^process', 'process'),
)
