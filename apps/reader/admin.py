from apps.reader.models import UserSubscription, UserStory, UserSubscriptionFolders
from django.contrib import admin

admin.site.register(UserSubscription)
admin.site.register(UserSubscriptionFolders)
admin.site.register(UserStory)