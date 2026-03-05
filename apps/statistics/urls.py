from django.urls import re_path

from apps.statistics import views

urlpatterns = [
    re_path(r"^dashboard_graphs", views.dashboard_graphs, name="statistics-graphs"),
    re_path(r"^feedback_table", views.feedback_table, name="feedback-table"),
    re_path(r"^revenue", views.revenue, name="revenue"),
    re_path(r"^slow", views.slow, name="slow"),
]
