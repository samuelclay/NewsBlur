from django.conf.urls import include, url, patterns
from django.conf import settings
from apps.reader import views as reader_views
from apps.social import views as social_views
from apps.static import views as static_views
from apps.profile import views as profile_views
from django.contrib import admin

admin.autodiscover()

urlpatterns = patterns('',
    url(r'^$',              reader_views.index, name='index'),
    (r'^reader/',           include('apps.reader.urls')),
    (r'^add/?',             reader_views.index),
    (r'^try/?',             reader_views.index),
    (r'^site/(?P<feed_id>\d+)?', reader_views.index),
    url(r'^folder/(?P<folder_name>\d+)?', reader_views.index, name='folder'),
    url(r'^saved/(?P<tag_name>\d+)?', reader_views.index, name='saved-stories-tag'),
    (r'^saved/?',           reader_views.index),
    (r'^read/?',            reader_views.index),
    (r'^social/\d+/.*?',    reader_views.index),
    (r'^user/.*?',          reader_views.index),
    (r'^null/.*?',          reader_views.index),
    (r'^story/.*?',         reader_views.index),
    (r'^feed/?',            social_views.shared_stories_rss_feed_noid),
    (r'^rss_feeds/',        include('apps.rss_feeds.urls')),
    (r'^classifier/',       include('apps.analyzer.urls')),
    (r'^profile/',          include('apps.profile.urls')),
    (r'^folder_rss/',       include('apps.profile.urls')),
    (r'^import/',           include('apps.feed_import.urls')),
    (r'^api/',              include('apps.api.urls')),
    (r'^recommendations/',  include('apps.recommendations.urls')),
    (r'^statistics/',       include('apps.statistics.urls')),
    (r'^social/',           include('apps.social.urls')),
    (r'^oauth/',            include('apps.oauth.urls')),
    (r'^mobile/',           include('apps.mobile.urls')),
    (r'^m/',                include('apps.mobile.urls')),
    (r'^push/',             include('apps.push.urls')),
    (r'^newsletters/',      include('apps.newsletters.urls')),
    (r'^categories/',       include('apps.categories.urls')),
    (r'^_haproxychk',       static_views.haproxy_check),
    (r'^_dbcheck/postgres', static_views.postgres_check),
    (r'^_dbcheck/mongo',    static_views.mongo_check),
    (r'^_dbcheck/redis',    static_views.redis_check),
    (r'^_dbcheck/elasticsearch', static_views.elasticsearch_check),
    url(r'^admin/',         include(admin.site.urls)),
    url(r'^about/?',        static_views.about, name='about'),
    url(r'^faq/?',          static_views.faq, name='faq'),
    url(r'^api/?',          static_views.api, name='api'),
    url(r'^press/?',        static_views.press, name='press'),
    url(r'^feedback/?',     static_views.feedback, name='feedback'),
    url(r'^ios/download/?', static_views.ios_download, name='ios-download'),
    url(r'^ios/NewsBlur.plist', static_views.ios_plist, name='ios-download-plist'),
    url(r'^ios/NewsBlur.ipa', static_views.ios_ipa, name='ios-download-ipa'),
    url(r'^ios/?',          static_views.ios, name='ios-static'),
    url(r'^iphone/?',       static_views.ios),
    url(r'^ipad/?',         static_views.ios),
    url(r'^android/?',      static_views.android, name='android-static'),
    url(r'^firefox/?',      static_views.firefox, name='firefox'),
    url(r'zebra/',          include('zebra.urls',  namespace="zebra",  app_name='zebra')),
    url(r'^account/redeem_code/?$', profile_views.redeem_code, name='redeem-code'),
    url(r'^account/login/?$', profile_views.login, name='login'),
    url(r'^account/signup/?$', profile_views.signup, name='signup'),
    url(r'^account/logout/?$', 
                            'django.contrib.auth.views.logout', 
                            {'next_page': '/'}, name='logout'),
    url(r'^account/ifttt/v1/', include('apps.oauth.urls')),
    url(r'^account/',       include('oauth2_provider.urls', namespace='oauth2_provider')),
)

if settings.DEBUG:
    urlpatterns += patterns('',
        (r'^media/(?P<path>.*)$', 'django.views.static.serve',
            {'document_root': settings.MEDIA_ROOT}),
    )
    urlpatterns += patterns('',
        (r'^static/(?P<path>.*)$', 'django.views.static.serve',
            {'document_root': settings.STATIC_ROOT}),
    )
