from django.conf.urls.defaults import *
from django.conf import settings

# Uncomment the next two lines to enable the admin:
from django.contrib import admin
admin.autodiscover()

urlpatterns = patterns('',
    (r'^$', include('apps.reader.urls')),
    (r'^accounts/', include('apps.registration.urls')),
    (r'^reader/', include('apps.reader.urls')),
    (r'^classifier/', include('apps.analyzer.urls')),
    (r'^opml/', include('apps.opml_import.urls')),
    (r'^admin/doc/', include('django.contrib.admindocs.urls')),
    (r'^admin/(.*)', admin.site.root)
)

if settings.DEVELOPMENT:
    urlpatterns += patterns('',
        (r'^media/(?P<path>.*)$', 'django.views.static.serve',
            {'document_root': settings.MEDIA_ROOT}),
    )
