from django.conf.urls import url, patterns
from apps.categories import views

urlpatterns = patterns('',
    url(r'^/?$', views.all_categories, name='all-categories'),
    url(r'^subscribe/?$', views.subscribe, name='categories-subscribe'),
)
