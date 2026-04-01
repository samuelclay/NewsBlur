from django.urls import re_path

from apps.discover import views

urlpatterns = [
    re_path(r"^autocomplete/?$", views.feed_autocomplete, name="feed-autocomplete"),
    re_path(r"^search_feed/?$", views.search_feed, name="search-feed"),
    re_path(r"^trending/?$", views.trending_sites, name="trending-sites"),
    re_path(r"^popular_channels/?$", views.popular_channels, name="popular-channels"),
    re_path(r"^popular_feeds/?$", views.popular_feeds, name="popular-feeds"),
    re_path(r"^link_popular_feed/?$", views.link_popular_feed, name="link-popular-feed"),
    re_path(r"^youtube/search/?$", views.youtube_search, name="youtube-search"),
    re_path(r"^reddit/search/?$", views.reddit_search, name="reddit-search"),
    re_path(r"^reddit/popular/?$", views.reddit_popular, name="reddit-popular"),
    re_path(r"^podcast/search/?$", views.podcast_search, name="podcast-search"),
    re_path(r"^newsletter/convert/?$", views.newsletter_convert, name="newsletter-convert"),
    re_path(r"^google-news/feed/?$", views.google_news_feed, name="google-news-feed"),
    re_path(r"^similar/(?P<feed_id>\d+)/?$", views.discover_feeds, name="discover-feeds"),
    re_path(r"^similar/feeds/?$", views.discover_feeds, name="discover-feeds-post"),
    re_path(r"^similar/stories/(?P<story_hash>\w+:[\w\d]+)/?$", views.discover_stories, name="discover-stories"),
    re_path(r"^index/?$", views.discover_index, name="discover-index"),
]
