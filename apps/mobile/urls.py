from django.urls import re_path

from apps.mobile import views

urlpatterns = [
    re_path(r"^$", views.index, name="mobile-index"),
]
