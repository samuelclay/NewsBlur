from django.conf.urls import url

from apps.discover import views

urlpatterns = [
    url(r"^autocomplete/?$", views.feed_autocomplete, name="feed-autocomplete"),
    url(r"^search_feed/?$", views.search_feed, name="search-feed"),
    url(r"^trending/?$", views.trending_sites, name="trending-sites"),
    url(r"^popular_channels/?$", views.popular_channels, name="popular-channels"),
    url(r"^youtube/search/?$", views.youtube_search, name="youtube-search"),
    url(r"^reddit/search/?$", views.reddit_search, name="reddit-search"),
    url(r"^reddit/popular/?$", views.reddit_popular, name="reddit-popular"),
    url(r"^podcast/search/?$", views.podcast_search, name="podcast-search"),
    url(r"^newsletter/convert/?$", views.newsletter_convert, name="newsletter-convert"),
    url(r"^google-news/feed/?$", views.google_news_feed, name="google-news-feed"),
    url(r"^similar/(?P<feed_id>\d+)/?$", views.discover_feeds, name="discover-feeds"),
    url(r"^similar/feeds/?$", views.discover_feeds, name="discover-feeds-post"),
    url(r"^similar/stories/(?P<story_hash>\w+:[\w\d]+)/?$", views.discover_stories, name="discover-stories"),
]
