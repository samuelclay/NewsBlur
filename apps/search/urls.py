from django.urls import re_path

from apps.search import views

urlpatterns = [
    # re_path(r'^$', views.index),
    re_path(r"^more_like_this", views.more_like_this, name="more-like-this"),
]
