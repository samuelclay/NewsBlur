from django.conf.urls import url

from apps.describe import views

urlpatterns = [
    url(r"^start/?$", views.start_search, name="describe-start"),
    url(r"^status/?$", views.search_status, name="describe-status"),
    url(r"^history/?$", views.search_history, name="describe-history"),
    url(r"^delete/?$", views.delete_search, name="describe-delete"),
]
