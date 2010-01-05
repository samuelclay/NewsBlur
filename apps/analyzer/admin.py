from apps.analyzer.models import ClassifierTitle, ClassifierAuthor, ClassifierFeed, ClassifierTag
from django.contrib import admin

admin.site.register(ClassifierTitle)
admin.site.register(ClassifierAuthor)
admin.site.register(ClassifierFeed)
admin.site.register(ClassifierTag)