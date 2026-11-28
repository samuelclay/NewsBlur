from django.conf.urls import url

from . import views

urlpatterns = [
    url(r"^status$", views.status, name="reorganize-status"),
    url(r"^locks$", views.save_locks, name="reorganize-locks"),
    url(r"^propose$", views.propose, name="reorganize-propose"),
    url(r"^decisions$", views.save_decisions, name="reorganize-decisions"),
    url(r"^revise$", views.revise, name="reorganize-revise"),
    url(r"^apply$", views.apply_proposal, name="reorganize-apply"),
    url(r"^undo$", views.undo_proposal, name="reorganize-undo"),
]
