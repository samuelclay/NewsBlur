from django.conf.urls import url

from apps.media_player import views

urlpatterns = [
    url(r"^save_playback_state", views.save_playback_state, name="save-playback-state"),
    url(r"^add_to_media_queue", views.add_to_media_queue, name="add-to-media-queue"),
    url(r"^remove_from_media_queue", views.remove_from_media_queue, name="remove-from-media-queue"),
    url(r"^reorder_media_queue", views.reorder_media_queue, name="reorder-media-queue"),
    url(r"^clear_playback_state", views.clear_playback_state, name="clear-playback-state"),
    url(r"^clear_media_queue", views.clear_media_queue, name="clear-media-queue"),
    url(r"^add_to_media_history", views.add_to_media_history, name="add-to-media-history"),
    url(r"^remove_from_media_history", views.remove_from_media_history, name="remove-from-media-history"),
    url(r"^clear_media_history", views.clear_media_history, name="clear-media-history"),
]
