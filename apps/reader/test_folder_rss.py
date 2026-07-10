import datetime
from contextlib import ExitStack
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from xml.etree import ElementTree

from django.test import RequestFactory, SimpleTestCase

from apps.reader import views


class Test_FolderRssFeed(SimpleTestCase):
    def test_link_free_story_uses_internal_story_permalink(self):
        request = RequestFactory().get("/reader/folder_rss/1/token/unread/folder/")
        profile = SimpleNamespace(
            has_scoped_classifiers=False,
            is_archive=True,
            is_premium=True,
            is_pro=False,
            premium_available_text_classifiers=False,
            timezone="UTC",
        )
        user = SimpleNamespace(pk=1, username="reader", profile=profile)
        folders = MagicMock()
        folders.feed_ids_under_folder_slug.return_value = ([1], "Folder")
        story = {
            "guid_hash": "abc123",
            "story_authors": "",
            "story_content": "Release notes",
            "story_date": datetime.datetime(2026, 7, 9, tzinfo=datetime.timezone.utc),
            "story_feed_id": 1,
            "story_permalink": None,
            "story_tags": [],
            "story_title": "Version 1.2.3",
        }
        story_query = MagicMock()
        story_query.order_by.return_value = [MagicMock()]
        subscription = SimpleNamespace(user_title="")

        classifier_functions = [
            "apply_classifier_authors",
            "apply_classifier_feeds",
            "apply_classifier_tags",
            "apply_classifier_text_regex",
            "apply_classifier_texts",
            "apply_classifier_title_regex",
            "apply_classifier_titles",
            "apply_classifier_url_regex",
            "apply_classifier_urls",
        ]

        with ExitStack() as stack:
            stack.enter_context(patch.object(views.cache, "get", return_value=None))
            stack.enter_context(patch.object(views.cache, "set"))
            stack.enter_context(
                patch.object(views.User.objects, "get", return_value=user)
            )
            stack.enter_context(
                patch.object(views, "get_object_or_404", return_value=folders)
            )
            stack.enter_context(
                patch.object(views.UserSubscription, "subs_for_feeds", return_value=[])
            )
            stack.enter_context(
                patch.object(
                    views.UserSubscription,
                    "feed_stories",
                    return_value=(["1:abc123"], set()),
                )
            )
            stack.enter_context(
                patch.object(views.UserSubscription, "score_story", return_value=0)
            )
            stack.enter_context(
                patch.object(
                    views.UserSubscription.objects, "get", return_value=subscription
                )
            )
            stack.enter_context(
                patch.object(views.MStory, "objects", return_value=story_query)
            )
            stack.enter_context(
                patch.object(views.Feed, "format_stories", return_value=[story])
            )
            stack.enter_context(
                patch.object(
                    views.Feed,
                    "get_by_id",
                    return_value=SimpleNamespace(feed_title="Web Feed"),
                )
            )
            stack.enter_context(
                patch.object(
                    views.Site.objects,
                    "get_current",
                    return_value=SimpleNamespace(domain="www.newsblur.com"),
                )
            )
            stack.enter_context(patch.object(views, "sort_classifiers_by_feed"))
            stack.enter_context(patch.object(views.logging, "user"))
            for function_name in classifier_functions:
                stack.enter_context(patch.object(views, function_name, return_value=0))

            response = views.folder_rss_feed.__wrapped__(
                request,
                user_id="1",
                secret_token="token",
                unread_filter="unread",
                folder_slug="folder",
            )

        root = ElementTree.fromstring(response.content)
        entry = root.find("{http://www.w3.org/2005/Atom}entry")
        link = entry.find("{http://www.w3.org/2005/Atom}link")
        self.assertEqual(link.attrib["href"], "https://www.newsblur.com/site/1/abc123/")
