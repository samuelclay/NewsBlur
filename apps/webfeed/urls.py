from django.conf.urls import url

from . import views

urlpatterns = [
    url(r"^analyze$", views.analyze, name="webfeed-analyze"),
    url(r"^subscribe$", views.subscribe, name="webfeed-subscribe"),
    url(r"^reanalyze$", views.reanalyze, name="webfeed-reanalyze"),
]
