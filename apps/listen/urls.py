from django.conf.urls import url

from . import views

# /listen/stream/<job>.mp3 is served by the node stream server (node/listen.coffee), routed there by HAProxy.
urlpatterns = [
    url(r"^voices$", views.listen_voices, name="listen-voices"),
    url(r"^library$", views.listen_library, name="listen-library"),
    url(r"^manifest$", views.listen_manifest, name="listen-manifest"),
    url(r"^segment$", views.listen_segment, name="listen-segment"),
    url(r"^preview$", views.listen_preview, name="listen-preview"),
    url(r"^usage$", views.listen_usage, name="listen-usage"),
    url(r"^progress$", views.listen_progress, name="listen-progress"),
]
