"""
URL routing for the Archive Extension API.

All endpoints are under /api/archive/
"""

from django.urls import path, re_path

from apps.archive_extension import views

urlpatterns = [
    # Ingestion endpoints (from browser extension)
    path("ingest", views.ingest, name="archive-ingest"),
    path("batch_ingest", views.batch_ingest, name="archive-batch-ingest"),
    # Listing and browsing
    path("list", views.list_archives, name="archive-list"),
    path("categories", views.get_categories, name="archive-categories"),
    path("domains", views.get_domains, name="archive-domains"),
    path("stats", views.get_stats, name="archive-stats"),
    # Management
    path("delete", views.delete_archives, name="archive-delete"),
    # Blocklist management
    path("blocklist", views.get_blocklist, name="archive-blocklist-get"),
    path("blocklist/update", views.update_blocklist, name="archive-blocklist-update"),
    # Export
    path("export", views.export_archives, name="archive-export"),
]
