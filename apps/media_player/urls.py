from django.urls import re_path

from apps.media_player import views

urlpatterns = [
    re_path(r"^save_playback_state", views.save_playback_state, name="save-playback-state"),
    re_path(r"^add_to_media_queue", views.add_to_media_queue, name="add-to-media-queue"),
    re_path(r"^remove_from_media_queue", views.remove_from_media_queue, name="remove-from-media-queue"),
    re_path(r"^reorder_media_queue", views.reorder_media_queue, name="reorder-media-queue"),
    re_path(r"^clear_playback_state", views.clear_playback_state, name="clear-playback-state"),
    re_path(r"^clear_media_queue", views.clear_media_queue, name="clear-media-queue"),
    re_path(r"^add_to_media_history", views.add_to_media_history, name="add-to-media-history"),
    re_path(r"^remove_from_media_history", views.remove_from_media_history, name="remove-from-media-history"),
    re_path(r"^clear_media_history", views.clear_media_history, name="clear-media-history"),
]
