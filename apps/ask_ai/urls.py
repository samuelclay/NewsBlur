from django.urls import re_path

from . import views

urlpatterns = [
    re_path(r"^question$", views.ask_ai_question, name="ask-ai-question"),
    re_path(r"^transcribe$", views.transcribe_audio, name="ask-ai-transcribe"),
]
