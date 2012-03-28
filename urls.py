from django.conf.urls.defaults import *
from django.conf import settings
from apps.reader import views as reader_views
from apps.static import views as static_views

urlpatterns = patterns('',
    url(r'^$',              reader_views.index, name='index'),
    (r'^reader/',           include('apps.reader.urls')),
    (r'^rss_feeds/',        include('apps.rss_feeds.urls')),
    (r'^classifier/',       include('apps.analyzer.urls')),
    (r'^profile/',          include('apps.profile.urls')),
    (r'^import/',           include('apps.feed_import.urls')),
    (r'^api/',              include('apps.api.urls')),
    (r'^recommendations/',  include('apps.recommendations.urls')),
    (r'^statistics/',       include('apps.statistics.urls')),
    (r'^mobile/',           include('apps.mobile.urls')),
    (r'^m/',                include('apps.mobile.urls')),
    (r'^push/',             include('apps.push.urls')),
    url(r'^about/?',        static_views.about, name='about'),
    url(r'^faq/?',          static_views.faq, name='faq'),
    url(r'^api/?',          static_views.api, name='api'),
    url(r'^press/?',        static_views.press, name='press'),
    url(r'^feedback/?',     static_views.feedback, name='feedback'),
    url(r'^iphone/?',       static_views.iphone, name='iphone'),
    url(r'zebra/',          include('zebra.urls',  namespace="zebra",  app_name='zebra')),
)

if settings.DEVELOPMENT:
    urlpatterns += patterns('',
        (r'^media/(?P<path>.*)$', 'django.views.static.serve',
            {'document_root': settings.MEDIA_ROOT}),
    )
    urlpatterns += patterns('',
        (r'^static/(?P<path>.*)$', 'django.views.static.serve',
            {'document_root': settings.STATIC_ROOT}),
    )
