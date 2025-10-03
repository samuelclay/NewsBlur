from django.contrib import admin

from apps.rss_feeds.models import Feed


class FeedAdmin(admin.ModelAdmin):
    raw_id_fields = ["branch_from_feed", "similar_feeds"]


admin.site.register(Feed, FeedAdmin)
