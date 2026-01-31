from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.contrib.auth.views import LogoutView
from django.urls import include, re_path

from apps.profile import views as profile_views
from apps.reader import views as reader_views
from apps.social import views as social_views
from apps.static import views as static_views

admin.autodiscover()

urlpatterns = [
    re_path(r"^$", reader_views.index, name="index"),
    re_path(r"^reader/", include("apps.reader.urls")),
    re_path(r"^ask-ai/", include("apps.ask_ai.urls")),
    re_path(r"^add/?", reader_views.index),
    re_path(r"^try/?", reader_views.index),
    re_path(r"^site/(?P<feed_id>\d+)?", reader_views.index),
    re_path(r"^folder/(?P<folder_name>\d+)?", reader_views.index, name="folder"),
    re_path(r"^saved/(?P<tag_name>\d+)?", reader_views.index, name="saved-stories-tag"),
    re_path(r"^saved/?", reader_views.index),
    re_path(r"^read/?", reader_views.index),
    re_path(r"^trending/?", reader_views.index),
    re_path(r"^archive/?$", reader_views.index),
    re_path(r"^social/\d+/.*?", reader_views.index),
    re_path(r"^user/.*?", reader_views.index),
    re_path(r"^null/.*?", reader_views.index),
    re_path(r"^story/.*?", reader_views.index),
    re_path(r"^feed/?", social_views.shared_stories_rss_feed_noid),
    re_path(r"^rss_feeds/", include("apps.rss_feeds.urls")),
    re_path(r"^analyzer/", include("apps.analyzer.urls")),
    re_path(r"^classifier/", include("apps.analyzer.urls")),
    re_path(r"^folder_rss/", include("apps.profile.urls")),
    re_path(r"^profile/", include("apps.profile.urls")),
    re_path(r"^import/", include("apps.feed_import.urls")),
    re_path(r"^api/", include("apps.api.urls")),
    re_path(r"^api/archive/", include("apps.archive_extension.urls")),
    re_path(r"^archive-assistant/", include("apps.archive_assistant.urls")),
    re_path(r"^recommendations/", include("apps.recommendations.urls")),
    re_path(r"^notifications/?", include("apps.notifications.urls")),
    re_path(r"^statistics/", include("apps.statistics.urls")),
    re_path(r"^social/", include("apps.social.urls")),
    re_path(r"^search/", include("apps.search.urls")),
    re_path(r"^oauth/", include("apps.oauth.urls")),
    re_path(r"^mobile/", include("apps.mobile.urls")),
    re_path(r"^m/", include("apps.mobile.urls")),
    re_path(r"^push/", include("apps.push.urls")),
    re_path(r"^newsletters/", include("apps.newsletters.urls")),
    re_path(r"^categories/", include("apps.categories.urls")),
    re_path(r"^_haproxychk", static_views.haproxy_check),
    re_path(r"^_dbcheck/postgres", static_views.postgres_check),
    re_path(r"^_dbcheck/mongo", static_views.mongo_check),
    re_path(r"^_dbcheck/redis", static_views.redis_check),
    re_path(r"^_dbcheck/elasticsearch", static_views.elasticsearch_check),
    re_path(r"^admin/", admin.site.urls),
    re_path(r"^about/?", static_views.about, name="about"),
    re_path(r"^faq/?", static_views.faq, name="faq"),
    re_path(r"^api/?$", static_views.api, name="api"),
    re_path(r"^press/?", static_views.press, name="press"),
    re_path(r"^feedback/?", static_views.feedback, name="feedback"),
    re_path(r"^privacy/?", static_views.privacy, name="privacy"),
    re_path(r"^tos/?", static_views.tos, name="tos"),
    re_path(r"^manifest.webmanifest", static_views.webmanifest, name="webmanifest"),
    re_path(
        r"^.well-known/apple-app-site-association",
        static_views.apple_app_site_assoc,
        name="apple-app-site-assoc",
    ),
    re_path(
        r"^.well-known/apple-developer-merchantid-domain-association",
        static_views.apple_developer_merchantid,
        name="apple-developer-merchantid",
    ),
    re_path(r"^ios/download/?", static_views.ios_download, name="ios-download"),
    re_path(r"^ios/NewsBlur.plist", static_views.ios_plist, name="ios-download-plist"),
    re_path(r"^ios/NewsBlur.ipa", static_views.ios_ipa, name="ios-download-ipa"),
    re_path(r"^ios/?", static_views.ios, name="ios-static"),
    re_path(r"^iphone/?", static_views.ios),
    re_path(r"^ipad/?", static_views.ios),
    re_path(r"^android/?", static_views.android, name="android-static"),
    re_path(r"^firefox/?", static_views.firefox, name="firefox"),
    re_path(r"zebra/", include("zebra.urls", namespace="zebra")),
    re_path(r"^account/redeem_code/?$", profile_views.redeem_code, name="redeem-code"),
    re_path(r"^account/login/?$", profile_views.login, name="login"),
    re_path(r"^account/signup/?$", profile_views.signup, name="signup"),
    re_path(r"^account/logout/?$", LogoutView.as_view(next_page="/"), name="logout"),
    re_path(r"^account/ifttt/v1/", include("apps.oauth.urls")),
    re_path(r"^account/", include("oauth2_provider.urls", namespace="oauth2_provider")),
    re_path(r"^monitor/", include("apps.monitor.urls"), name="monitor"),
    re_path(r"^health-check/?", static_views.health_check, name="health-check"),
    re_path("", include("django_prometheus.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
