from apps.reader.models import UserSubscription, UserStory, UserSubscriptionFolders, Feature
from django.contrib import admin

admin.site.register(UserSubscription)
admin.site.register(UserSubscriptionFolders)
admin.site.register(UserStory)
admin.site.register(Feature)