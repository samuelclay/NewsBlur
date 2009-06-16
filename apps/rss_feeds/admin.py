from apps.rss_feeds.models import Feed, Story, Tag
from django.contrib import admin

admin.site.register(Feed)
admin.site.register(Story)
admin.site.register(Tag)