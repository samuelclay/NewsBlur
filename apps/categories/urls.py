from django.urls import re_path

from apps.categories import views

urlpatterns = [
    re_path(r"^$", views.all_categories, name="all-categories"),
    re_path(r"^subscribe/?$", views.subscribe, name="categories-subscribe"),
]
