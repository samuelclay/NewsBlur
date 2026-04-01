from django.urls import re_path
from django.views.generic import RedirectView

from apps.rss_feeds import views


# HTTP 308 Permanent Redirect preserves request method (important for POST requests)
class PermanentRedirectView(RedirectView):
    permanent = True

    def get_redirect_url(self, *args, **kwargs):
        url = super().get_redirect_url(*args, **kwargs)
        # Preserve query string
        if self.request.META.get("QUERY_STRING"):
            url = f"{url}?{self.request.META['QUERY_STRING']}"
        return url

    def get(self, request, *args, **kwargs):
        response = super().get(request, *args, **kwargs)
        response.status_code = 308  # Permanent Redirect that preserves method
        return response

    def post(self, request, *args, **kwargs):
        return self.get(request, *args, **kwargs)


urlpatterns = [
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
    # Backward compatibility redirects for pre-existing endpoints moved to /discover/
    # HTTP 308 preserves request method (important for POST requests)
    re_path(
        r"^feed_autocomplete/?$",
        PermanentRedirectView.as_view(url="/discover/autocomplete"),
        name="feed-autocomplete-redirect",
    ),
    re_path(
        r"^search_feed/?$",
        PermanentRedirectView.as_view(url="/discover/search_feed"),
        name="search-feed-redirect",
    ),
    re_path(
        r"^trending_sites/?$",
        PermanentRedirectView.as_view(url="/discover/trending"),
        name="trending-sites-redirect",
    ),
    re_path(
        r"^discover/(?P<feed_id>\d+)/?$",
        PermanentRedirectView.as_view(url="/discover/similar/%(feed_id)s"),
        name="discover-feed",
    ),
    re_path(
        r"^discover/feeds/?$",
        PermanentRedirectView.as_view(url="/discover/similar/feeds"),
        name="discover-feeds-redirect",
    ),
    re_path(
        r"^discover/stories/(?P<story_hash>\w+:\w+)/?$",
        PermanentRedirectView.as_view(url="/discover/similar/stories/%(story_hash)s"),
        name="discover-stories-redirect",
    ),
]
