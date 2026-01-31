from django.urls import re_path

from apps.rss_feeds import views

urlpatterns = [
    re_path(r"^feed_autocomplete", views.feed_autocomplete, name="feed-autocomplete"),
    re_path(r"^search_feed", views.search_feed, name="search-feed"),
    re_path(r"^statistics/(?P<feed_id>\d+)", views.load_feed_statistics, name="feed-statistics"),
    re_path(
        r"^statistics_embedded/(?P<feed_id>\d+)",
        views.load_feed_statistics_embedded,
        name="feed-statistics-embedded",
    ),
    re_path(r"^feed_settings/(?P<feed_id>\d+)", views.load_feed_settings, name="feed-settings"),
    re_path(r"^feed/(?P<feed_id>\d+)/?", views.load_single_feed, name="feed-info"),
    re_path(r"^icon/(?P<feed_id>\d+)/?", views.load_feed_favicon, name="feed-favicon"),
    re_path(r"^exception_retry", views.exception_retry, name="exception-retry"),
    re_path(
        r"^exception_change_feed_address",
        views.exception_change_feed_address,
        name="exception-change-feed-address",
    ),
    re_path(r"^exception_change_feed_link", views.exception_change_feed_link, name="exception-change-feed-link"),
    re_path(r"^status", views.status, name="status"),
    re_path(r"^load_single_feed", views.load_single_feed, name="feed-canonical"),
    re_path(r"^original_text", views.original_text, name="original-text"),
    re_path(r"^original_story", views.original_story, name="original-story"),
    re_path(r"^story_changes", views.story_changes, name="story-changes"),
    re_path(r"^discover/(?P<feed_id>\d+)/?$", views.discover_feeds, name="discover-feed"),
    re_path(r"^discover/feeds/?$", views.discover_feeds, name="discover-feeds"),
    re_path(r"^discover/stories/(?P<story_hash>\w+:\w+)/?$", views.discover_stories, name="discover-stories"),
    re_path(r"^trending_sites/?$", views.trending_sites, name="trending-sites"),
]
