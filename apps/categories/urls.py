from django.conf.urls import url
from apps.categories import views

urlpatterns = [
    url(r'^/?$', views.all_categories, name='all-categories'),
    url(r'^subscribe/?$', views.subscribe, name='categories-subscribe'),
]
