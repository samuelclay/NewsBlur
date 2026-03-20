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

        # Classifiers without is_regex: single aggregation groups by scope
        scope_only_classifiers = [
            ("authors", MClassifierAuthor),
            ("tags", MClassifierTag),
        ]

        scopes = ["feed", "folder", "global"]

        for name, cls in scope_only_classifiers:
            # One aggregation per collection instead of 3 separate count queries
            scope_counts = self._count_by_scope(cls)
            for scope in scopes:
                data[f"{name}_{scope}"] = scope_counts.get(scope, 0)

        # Classifiers with is_regex: single aggregation groups by scope + is_regex
        regex_classifiers = [
            ("texts", MClassifierText),
            ("titles", MClassifierTitle),
            ("urls", MClassifierUrl),
        ]

        for name, cls in regex_classifiers:
            counts = self._count_by_scope_and_regex(cls)
            for scope in scopes:
                data[f"{name}_{scope}"] = counts.get((scope, False), 0) + counts.get((scope, True), 0)
                data[f"{name}_regex_{scope}"] = counts.get((scope, True), 0)

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
        """Single aggregation to count documents grouped by scope.

        Documents without a scope field are counted as "feed" (the default).
        """
        pipeline = [
            {"$group": {"_id": "$scope", "count": {"$sum": 1}}},
        ]
        results = cls.objects._collection.aggregate(pipeline)
        counts = {}
        for row in results:
            scope = row["_id"] or "feed"
            counts[scope] = counts.get(scope, 0) + row["count"]
        return counts

    def _count_by_scope_and_regex(self, cls):
        """Single aggregation to count documents grouped by scope and is_regex.

        Documents without a scope field are counted as "feed".
        Returns dict keyed by (scope, is_regex) tuples.
        """
        pipeline = [
            {"$group": {"_id": {"scope": "$scope", "is_regex": "$is_regex"}, "count": {"$sum": 1}}},
        ]
        results = cls.objects._collection.aggregate(pipeline)
        counts = {}
        for row in results:
            scope = row["_id"].get("scope") or "feed"
            is_regex = bool(row["_id"].get("is_regex"))
            key = (scope, is_regex)
            counts[key] = counts.get(key, 0) + row["count"]
        return counts
