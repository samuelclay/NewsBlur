"""
URL routing for the Archive Assistant API.

All endpoints are under /archive-assistant/
"""

from django.urls import path

from apps.archive_assistant import views

urlpatterns = [
    # Query submission
    path("query", views.submit_query, name="archive-assistant-query"),
    # Conversations
    path("conversations", views.get_conversations, name="archive-assistant-conversations"),
    path("conversation/<str:conversation_id>", views.get_conversation, name="archive-assistant-conversation"),
    path(
        "conversation/<str:conversation_id>/delete",
        views.delete_conversation,
        name="archive-assistant-conversation-delete",
    ),
    # Suggestions and usage
    path("suggestions", views.get_suggestions, name="archive-assistant-suggestions"),
    path("usage", views.get_usage, name="archive-assistant-usage"),
]
