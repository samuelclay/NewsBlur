from django.conf.urls.defaults import *
from django.conf import settings
from apps.reader import views as reader_views
from django.contrib import admin
admin.autodiscover()

urlpatterns = patterns('',
    url(r'^$', reader_views.index, name='index'),
    (r'^reader/', include('apps.reader.urls')),
    (r'^rss_feeds/', include('apps.rss_feeds.urls')),
    (r'^classifier/', include('apps.analyzer.urls')),
    (r'^profile/', include('apps.profile.urls')),
    (r'^import/', include('apps.feed_import.urls')),
    (r'^admin/doc/', include('django.contrib.admindocs.urls')),
    (r'^admin/(.*)', admin.site.root)
)

if settings.DEVELOPMENT:
    urlpatterns += patterns('',
        (r'^media/(?P<path>.*)$', 'django.views.static.serve',
            {'document_root': settings.MEDIA_ROOT}),
    )
