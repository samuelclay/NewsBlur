from django.conf.urls import url

from apps.briefing import views

urlpatterns = [
    url(r"^stories$", views.load_briefing_stories, name="load-briefing-stories"),
    url(r"^preferences$", views.briefing_preferences, name="briefing-preferences"),
    url(r"^status$", views.briefing_status, name="briefing-status"),
    url(r"^generate$", views.generate_briefing, name="generate-briefing"),
]
