from django.conf.urls import url
from apps.feed_import import views

urlpatterns = [
    url(r'^opml_upload/?$', views.opml_upload, name='opml-upload'),
    url(r'^opml_export/?$', views.opml_export, name='opml-export'),
]
