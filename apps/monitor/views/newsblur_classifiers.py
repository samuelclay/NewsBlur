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

        # MClassifierFeed has no scope field - it's always feed-scoped
        data["feeds"] = MClassifierFeed.objects._collection.count()

        # Classifier types that support scope
        scoped_classifiers = [
            ("authors", MClassifierAuthor),
            ("tags", MClassifierTag),
            ("texts", MClassifierText),
            ("titles", MClassifierTitle),
            ("urls", MClassifierUrl),
        ]

        scopes = ["feed", "folder", "global"]

        for name, cls in scoped_classifiers:
            for scope in scopes:
                # Count classifiers by scope
                # Note: Documents without scope field default to "feed"
                if scope == "feed":
                    # Include docs where scope is "feed" OR scope field doesn't exist
                    count = cls.objects(
                        __raw__={"$or": [{"scope": "feed"}, {"scope": {"$exists": False}}]}
                    ).count()
                else:
                    count = cls.objects(scope=scope).count()
                data[f"{name}_{scope}"] = count

        # Regex counts by scope (only titles, texts, urls support is_regex)
        regex_classifiers = [
            ("titles", MClassifierTitle),
            ("texts", MClassifierText),
            ("urls", MClassifierUrl),
        ]

        for name, cls in regex_classifiers:
            for scope in scopes:
                if scope == "feed":
                    count = cls.objects(
                        is_regex=True,
                        __raw__={"$or": [{"scope": "feed"}, {"scope": {"$exists": False}}]},
                    ).count()
                else:
                    count = cls.objects(is_regex=True, scope=scope).count()
                data[f"{name}_regex_{scope}"] = count

        chart_name = "classifiers"
        chart_type = "counter"

        formatted_data = {}

        # Format feeds (no scope label since it's always feed-scoped)
        formatted_data["feeds"] = f'{chart_name}{{classifier="feeds"}} {data["feeds"]}'

        # Format scoped classifiers
        for name, _ in scoped_classifiers:
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
