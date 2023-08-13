from django.conf.urls import url
from apps.discover import views

urlpatterns = [
    url(r'^feeds/?$', views.discover_feeds, name='discover-feeds'),
]
