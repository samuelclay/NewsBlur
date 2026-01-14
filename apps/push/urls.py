from django.urls import re_path

from apps.push import views

urlpatterns = [
    re_path(r"^(?P<push_id>\d+)/?$", views.push_callback, name="push-callback"),
]
