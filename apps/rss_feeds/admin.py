from apps.rss_feeds.models import Feed
from apps.reader.models import UserSubscription
from django.contrib import admin

class FeedAdmin(admin.ModelAdmin):
    search_fields = ('feed_address',)

admin.site.register(Feed, FeedAdmin)
