from django.urls import re_path
from zebra import views

app_name = "zebra"

urlpatterns = [
    re_path(r"webhooks/$", views.webhooks, name="webhooks"),
    re_path(r"webhooks/v2/$", views.webhooks_v2, name="webhooks_v2"),
]
