from django.shortcuts import render
from django.views import View

from apps.analyzer.models import (
    MClassifierAuthor,
    MClassifierFeed,
    MClassifierTag,
    MClassifierText,
    MClassifierTitle,
    MClassifierUrl,
)


class Classifiers(View):
    def get(self, request):
        data = {}

        # MClassifierFeed has no scope field - O(1) metadata lookup
        data["feeds"] = MClassifierFeed.objects._collection.estimated_document_count()

        # Classifiers without is_regex
        scope_only_classifiers = [
            ("authors", MClassifierAuthor),
            ("tags", MClassifierTag),
        ]

        scopes = ["feed", "folder", "global"]

        for name, cls in scope_only_classifiers:
            scope_counts = self._count_by_scope(cls)
            for scope in scopes:
                data[f"{name}_{scope}"] = scope_counts.get(scope, 0)

        # Classifiers with is_regex
        regex_classifiers = [
            ("texts", MClassifierText),
            ("titles", MClassifierTitle),
            ("urls", MClassifierUrl),
        ]

        for name, cls in regex_classifiers:
            scope_counts = self._count_by_scope(cls)
            regex_counts = self._count_regex_by_scope(cls)
            for scope in scopes:
                data[f"{name}_{scope}"] = scope_counts.get(scope, 0)
                data[f"{name}_regex_{scope}"] = regex_counts.get(scope, 0)

        chart_name = "classifiers"
        chart_type = "counter"

        formatted_data = {}

        # Format feeds (no scope label since it's always feed-scoped)
        formatted_data["feeds"] = f'{chart_name}{{classifier="feeds"}} {data["feeds"]}'

        # Format scoped classifiers
        all_classifiers = scope_only_classifiers + regex_classifiers
        for name, _ in all_classifiers:
            for scope in scopes:
                key = f"{name}_{scope}"
                formatted_data[key] = f'{chart_name}{{classifier="{name}",scope="{scope}"}} {data[key]}'

        # Format regex classifiers by scope
        for name, _ in regex_classifiers:
            for scope in scopes:
                key = f"{name}_regex_{scope}"
                formatted_data[key] = f'{chart_name}{{classifier="{name}_regex",scope="{scope}"}} {data[key]}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")

    def _count_by_scope(self, cls):
        """Count documents by scope using estimated total and indexed minority counts.

        Uses estimated_document_count() for O(1) total, then fast indexed counts
        for the small "folder" and "global" subsets. Feed count is derived by
        subtraction to avoid scanning millions of feed-scoped documents.
        """
        coll = cls.objects._collection
        total = coll.estimated_document_count()
        folder = coll.count_documents({"scope": "folder"})
        global_ = coll.count_documents({"scope": "global"})
        return {
            "feed": total - folder - global_,
            "folder": folder,
            "global": global_,
        }

    def _count_regex_by_scope(self, cls):
        """Count regex classifiers by scope. Very few regex docs exist so all counts are fast."""
        coll = cls.objects._collection
        total_regex = coll.count_documents({"is_regex": True})
        folder = coll.count_documents({"is_regex": True, "scope": "folder"})
        global_ = coll.count_documents({"is_regex": True, "scope": "global"})
        return {
            "feed": total_regex - folder - global_,
            "folder": folder,
            "global": global_,
        }
