from django.contrib import admin

from apps.reader.models import Feature, UserSubscription, UserSubscriptionFolders

admin.site.register(UserSubscription)
admin.site.register(UserSubscriptionFolders)
admin.site.register(Feature)
