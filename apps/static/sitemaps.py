"""Sitemap definitions for public-facing pages."""

from django.contrib.sitemaps import Sitemap
from django.urls import reverse


class StaticSitemap(Sitemap):
    changefreq = "weekly"
    priority = 0.8

    def items(self):
        return [
            "index",
            "features",
            "pricing",
            "about",
            "faq",
            "compare-feedly",
            "compare-inoreader",
            "compare-readwise",
            "compare-the-old-reader",
            "alt-open-source",
            "alt-self-hosted",
            "alt-google-reader",
            "alt-feedly",
            "alt-inoreader",
            "compare-feedbin",
            "feature-intelligence-training",
            "feature-ask-ai",
            "feature-web-feeds",
            "feature-newsletters",
            "feature-search",
            "feature-archive",
            "feature-saved-stories",
            "feature-native-apps",
            "pricing-premium",
            "pricing-archive",
            "pricing-pro",
            "press",
            "privacy",
            "tos",
            "ios-static",
            "android-static",
        ]

    def location(self, item):
        return reverse(item)
