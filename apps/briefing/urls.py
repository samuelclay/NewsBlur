from django.urls import re_path

from apps.briefing import views

urlpatterns = [
    re_path(r"^stories$", views.load_briefing_stories, name="load-briefing-stories"),
    re_path(r"^preferences$", views.briefing_preferences, name="briefing-preferences"),
    re_path(r"^generate$", views.generate_briefing, name="generate-briefing"),
    re_path(r"^admin/all$", views.load_all_briefings_admin, name="load-all-briefings-admin"),
]
