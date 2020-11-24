from django.conf.urls import url
from apps.mobile import views

urlpatterns = [
    url(r'^$', views.index, name='mobile-index'),
]
