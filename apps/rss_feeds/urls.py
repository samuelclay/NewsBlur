from django.conf.urls import url, patterns
from apps.rss_feeds import views

urlpatterns = patterns('',
    url(r'^feed_autocomplete', views.feed_autocomplete, name='feed-autocomplete'),
    url(r'^search_feed', views.search_feed, name='search-feed'),
    url(r'^statistics/(?P<feed_id>\d+)', views.load_feed_statistics, name='feed-statistics'),
    url(r'^feed_settings/(?P<feed_id>\d+)', views.load_feed_settings, name='feed-settings'),
    url(r'^feed/(?P<feed_id>\d+)/?', views.load_single_feed, name='feed-info'),
    url(r'^icon/(?P<feed_id>\d+)/?', views.load_feed_favicon, name='feed-favicon'),
    url(r'^exception_retry', views.exception_retry, name='exception-retry'),
    url(r'^exception_change_feed_address', views.exception_change_feed_address, name='exception-change-feed-address'),
    url(r'^exception_change_feed_link', views.exception_change_feed_link, name='exception-change-feed-link'),
    url(r'^status', views.status, name='status'),
    url(r'^load_single_feed', views.load_single_feed, name='feed-canonical'),
    url(r'^original_text', views.original_text, name='original-text'),
    url(r'^original_story', views.original_story, name='original-story'),
    url(r'^story_changes', views.story_changes, name='story-changes'),
)
