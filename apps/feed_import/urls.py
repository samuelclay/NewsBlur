from django.urls import re_path

from apps.feed_import import views

urlpatterns = [
    re_path(r"^opml_upload/?$", views.opml_upload, name="opml-upload"),
    re_path(r"^opml_export/?$", views.opml_export, name="opml-export"),
]
