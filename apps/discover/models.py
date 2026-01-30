from django.db import models

from apps.rss_feeds.models import Feed


class PopularFeed(models.Model):
    FEED_TYPE_CHOICES = [
        ("youtube", "YouTube"),
        ("reddit", "Reddit"),
        ("newsletter", "Newsletter"),
        ("podcast", "Podcast"),
    ]

    feed = models.ForeignKey(Feed, null=True, blank=True, on_delete=models.CASCADE, related_name="popular_entries")
    feed_url = models.URLField(max_length=764)
    feed_type = models.CharField(max_length=20, choices=FEED_TYPE_CHOICES, db_index=True)
    category = models.CharField(max_length=50, db_index=True)
    subcategory = models.CharField(max_length=50, db_index=True, blank=True, default="")
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True, default="")
    thumbnail_url = models.URLField(max_length=1000, blank=True, default="")
    platform = models.CharField(max_length=50, blank=True, default="")
    subscriber_count = models.IntegerField(default=0)
    sort_order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True, db_index=True)
    created_date = models.DateTimeField(auto_now_add=True)
    updated_date = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["feed_type", "category", "subcategory", "sort_order", "-subscriber_count"]
        unique_together = [("feed_url", "feed_type")]
        indexes = [
            models.Index(fields=["feed_type", "category"]),
            models.Index(fields=["feed_type", "is_active"]),
            models.Index(fields=["feed_type", "category", "subcategory"]),
        ]

    def __str__(self):
        if self.subcategory:
            return f"{self.feed_type}/{self.category}/{self.subcategory}: {self.title}"
        return f"{self.feed_type}/{self.category}: {self.title}"
