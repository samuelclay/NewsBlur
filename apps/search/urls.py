from django.conf.urls import *
from apps.search import views

urlpatterns = [
    # url(r'^$', views.index),
    url(r'^more_like_this', views.more_like_this, name='more-like-this'),
]
