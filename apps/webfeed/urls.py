from django.urls import re_path

from . import views

urlpatterns = [
    re_path(r"^analyze$", views.analyze, name="webfeed-analyze"),
    re_path(r"^subscribe$", views.subscribe, name="webfeed-subscribe"),
    re_path(r"^reanalyze$", views.reanalyze, name="webfeed-reanalyze"),
]
