from django.conf.urls import include, url
from django.conf import settings
from apps.reader import views as reader_views
from apps.social import views as social_views
from apps.static import views as static_views
from apps.profile import views as profile_views
from django.conf.urls.static import static
from django.contrib import admin
from django.contrib.auth.views import LogoutView

admin.autodiscover()

urlpatterns = [
    url(r'^$',              reader_views.index, name='index'),
    url(r'^reader/',        include('apps.reader.urls')),
    url(r'^add/?',          reader_views.index),
    url(r'^try/?',          reader_views.index),
    url(r'^site/(?P<feed_id>\d+)?', reader_views.index),
    url(r'^folder/(?P<folder_name>\d+)?', reader_views.index, name='folder'),
    url(r'^saved/(?P<tag_name>\d+)?', reader_views.index, name='saved-stories-tag'),
    url(r'^saved/?',           reader_views.index),
    url(r'^read/?',            reader_views.index),
    url(r'^social/\d+/.*?',    reader_views.index),
    url(r'^user/.*?',          reader_views.index),
    url(r'^null/.*?',          reader_views.index),
    url(r'^story/.*?',         reader_views.index),
    url(r'^feed/?',            social_views.shared_stories_rss_feed_noid),
    url(r'^rss_feeds/',        include('apps.rss_feeds.urls')),
    url(r'^analyzer/',         include('apps.analyzer.urls')),
    url(r'^classifier/',       include('apps.analyzer.urls')),
    url(r'^folder_rss/',       include('apps.profile.urls')),
    url(r'^profile/',          include('apps.profile.urls')),
    url(r'^import/',           include('apps.feed_import.urls')),
    url(r'^api/',              include('apps.api.urls')),
    url(r'^recommendations/',  include('apps.recommendations.urls')),
    url(r'^notifications/?',   include('apps.notifications.urls')),
    url(r'^statistics/',       include('apps.statistics.urls')),
    url(r'^social/',           include('apps.social.urls')),
    url(r'^search/',           include('apps.search.urls')),
    url(r'^oauth/',            include('apps.oauth.urls')),
    url(r'^mobile/',           include('apps.mobile.urls')),
    url(r'^m/',                include('apps.mobile.urls')),
    url(r'^push/',             include('apps.push.urls')),
    url(r'^newsletters/',      include('apps.newsletters.urls')),
    url(r'^categories/',       include('apps.categories.urls')),
    url(r'^_haproxychk',       static_views.haproxy_check),
    url(r'^_dbcheck/postgres', static_views.postgres_check),
    url(r'^_dbcheck/mongo',    static_views.mongo_check),
    url(r'^_dbcheck/redis',    static_views.redis_check),
    url(r'^_dbcheck/elasticsearch', static_views.elasticsearch_check),
    url(r'^admin/',         admin.site.urls),
    url(r'^about/?',        static_views.about, name='about'),
    url(r'^faq/?',          static_views.faq, name='faq'),
    url(r'^api/?$',         static_views.api, name='api'),
    url(r'^press/?',        static_views.press, name='press'),
    url(r'^feedback/?',     static_views.feedback, name='feedback'),
    url(r'^privacy/?',      static_views.privacy, name='privacy'),
    url(r'^tos/?',          static_views.tos, name='tos'),
    url(r'^manifest.webmanifest',          static_views.webmanifest, name='webmanifest'),
    url(r'^.well-known/apple-app-site-association',     static_views.apple_app_site_assoc, name='apple-app-site-assoc'),
    url(r'^.well-known/apple-developer-merchantid-domain-association',     static_views.apple_developer_merchantid, name='apple-developer-merchantid'),
    url(r'^ios/download/?', static_views.ios_download, name='ios-download'),
    url(r'^ios/NewsBlur.plist', static_views.ios_plist, name='ios-download-plist'),
    url(r'^ios/NewsBlur.ipa', static_views.ios_ipa, name='ios-download-ipa'),
    url(r'^ios/?',          static_views.ios, name='ios-static'),
    url(r'^iphone/?',       static_views.ios),
    url(r'^ipad/?',         static_views.ios),
    url(r'^android/?',      static_views.android, name='android-static'),
    url(r'^firefox/?',      static_views.firefox, name='firefox'),
    url(r'zebra/',          include('zebra.urls',  namespace="zebra")),
    url(r'^account/redeem_code/?$', profile_views.redeem_code, name='redeem-code'),
    url(r'^account/login/?$', profile_views.login, name='login'),
    url(r'^account/signup/?$', profile_views.signup, name='signup'),
    url(r'^account/logout/?$', 
                            LogoutView, 
                            {'next_page': '/'}, name='logout'),
    url(r'^account/ifttt/v1/', include('apps.oauth.urls')),
    url(r'^account/',       include('oauth2_provider.urls', namespace='oauth2_provider')),
    url(r'^monitor/', include('apps.monitor.urls'), name="monitor"),
    url('', include('django_prometheus.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
