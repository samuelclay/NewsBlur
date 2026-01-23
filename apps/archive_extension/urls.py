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
    # Category management
    path("categories/merge", views.merge_categories, name="archive-categories-merge"),
    path("categories/rename", views.rename_category, name="archive-categories-rename"),
    path("categories/split", views.split_category, name="archive-categories-split"),
    path(
        "categories/suggest-merges", views.suggest_category_merges, name="archive-categories-suggest-merges"
    ),
    path("categories/bulk-categorize", views.bulk_categorize, name="archive-categories-bulk"),
    path("recategorize", views.recategorize_archives, name="archive-recategorize"),
    # Management
    path("delete", views.delete_archives, name="archive-delete"),
    path("delete_by_domain", views.delete_archives_by_domain, name="archive-delete-by-domain"),
    # Blocklist management
    path("blocklist", views.get_blocklist, name="archive-blocklist-get"),
    path("blocklist/update", views.update_blocklist, name="archive-blocklist-update"),
    # Export
    path("export", views.export_archives, name="archive-export"),
]
