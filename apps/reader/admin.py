from apps.reader.models import UserSubscription, ReadStories, UserSubscriptionFolders, StoryOpinions
from django.contrib import admin

admin.site.register(UserSubscription)
admin.site.register(ReadStories)
admin.site.register(UserSubscriptionFolders)
admin.site.register(StoryOpinions)