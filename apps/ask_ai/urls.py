from django.conf.urls import url

from . import views

urlpatterns = [
    url(r"^question$", views.ask_ai_question, name="ask-ai-question"),
]
