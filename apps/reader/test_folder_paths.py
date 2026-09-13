import json
from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import RequestFactory, SimpleTestCase

from apps.reader.models import UserSubscriptionFolders
from apps.reader import views
from utils.feed_functions import add_object_to_folder
from utils.folder_paths import InvalidFolderPath, parse_folder_path, resolve_folder_path


class Test_FolderPaths(SimpleTestCase):
    def setUp(self):
        self.tree = [1, {"Blogs": [{"Links": [2, {"People": [3]}]}]}, {"Art": [{"Links": [4]}]}]
        self.folders = UserSubscriptionFolders(
            user=User(id=1, username="folder-test"), folders=json.dumps(self.tree)
        )
        self.save = patch.object(UserSubscriptionFolders, "save").start()
        patch("apps.reader.models.logging.user").start()
        self.addCleanup(patch.stopall)

    def test_add_feed_selects_exact_subfolder(self):
        add_object_to_folder(5, ["Art", "Links"], self.tree)
        self.assertEqual([4, 5], resolve_folder_path(self.tree, ["Art", "Links"]))
        self.assertEqual([2, {"People": [3]}], resolve_folder_path(self.tree, ["Blogs", "Links"]))

    def test_add_folder_supports_arbitrary_depth_and_root(self):
        self.folders.add_folder(["Blogs", "Links", "People"], "Friends")
        self.assertEqual(
            [], resolve_folder_path(json.loads(self.folders.folders), ["Blogs", "Links", "People", "Friends"])
        )
        self.folders.add_folder([], "Work")
        self.assertEqual([], resolve_folder_path(json.loads(self.folders.folders), ["Work"]))

    def test_move_only_removes_selected_placement(self):
        self.tree.append({"Other": [2]})
        self.folders.folders = json.dumps(self.tree)
        self.folders.move_feed_to_folders(2, [["Blogs", "Links"]], [["Art", "Links"]])
        result = json.loads(self.folders.folders)
        self.assertEqual([2], resolve_folder_path(result, ["Other"]))
        self.assertEqual([4, 2], resolve_folder_path(result, ["Art", "Links"]))
        self.assertEqual([{"People": [3]}], resolve_folder_path(result, ["Blogs", "Links"]))

    def test_stale_move_destination_does_not_remove_source(self):
        original = self.folders.folders
        with self.assertRaises(InvalidFolderPath):
            self.folders.move_feed_to_folders(2, [["Blogs", "Links"]], [["Missing", "Links"]])
        self.assertEqual(original, self.folders.folders)
        self.save.assert_not_called()

    def test_stale_delete_does_not_fall_back_to_other_folder(self):
        original = self.folders.folders
        with self.assertRaises(InvalidFolderPath):
            self.folders.delete_feed(2, ["Art", "Links"], commit_delete=False)
        self.assertEqual(original, self.folders.folders)
        self.save.assert_not_called()

    def test_rename_and_delete_exact_parent(self):
        self.folders.rename_folder("Links", "References", ["Art"])
        result = json.loads(self.folders.folders)
        self.assertEqual([4], resolve_folder_path(result, ["Art", "References"]))
        self.assertEqual([2, {"People": [3]}], resolve_folder_path(result, ["Blogs", "Links"]))
        self.folders.delete_folder("People", ["Blogs", "Links"], [], commit_delete=False)
        self.assertEqual([2], resolve_folder_path(json.loads(self.folders.folders), ["Blogs", "Links"]))

    def test_names_with_separators_and_unicode_are_literal_components(self):
        tree = [{"A ▸ B": [{"日本語 - Links": []}]}]
        add_object_to_folder(7, ["A ▸ B", "日本語 - Links"], tree)
        self.assertEqual([7], resolve_folder_path(tree, ["A ▸ B", "日本語 - Links"]))

    def test_classifier_path_lookup_preserves_literal_separators(self):
        path = "A - B - 日本語 - Links"
        self.assertEqual(path, views._find_full_folder_path({path: []}, "日本語 - Links", ["A - B"]))
        self.assertIsNone(views._find_full_folder_path({path: []}, "日本語 - Links", ["Other"]))

    def test_legacy_leaf_requests_still_work(self):
        self.folders.add_folder("People", "Friends")
        self.assertEqual(
            [], resolve_folder_path(json.loads(self.folders.folders), ["Blogs", "Links", "People", "Friends"])
        )

    def test_path_parameter_distinguishes_root_missing_and_invalid(self):
        factory = RequestFactory()
        self.assertEqual([], parse_folder_path(factory.post("/", {"folder_path": "[]"}), "folder_path"))
        self.assertIsNone(parse_folder_path(factory.post("/"), "folder_path"))
        for value in ["null", '"Links"', "[1]", '[""]', "[broken"]:
            with self.subTest(value=value), self.assertRaises(InvalidFolderPath):
                parse_folder_path(factory.post("/", {"folder_path": value}), "folder_path")

    def request(self, data):
        request = RequestFactory().post("/reader/folder", data)
        request.user = self.folders.user
        return request

    def test_add_folder_endpoint_prefers_full_parent_over_legacy_leaf(self):
        request = self.request(
            {"folder": "Friends", "parent_folder": "Links", "parent_folder_path": '["Art","Links"]'}
        )
        with patch.object(
            UserSubscriptionFolders.objects, "get_or_create", return_value=(self.folders, False)
        ), patch.object(views.redis, "Redis"):
            result = json.loads(views.add_folder(request).content)
        self.assertEqual(1, result["code"])
        self.assertEqual([], resolve_folder_path(result["folders"], ["Art", "Links", "Friends"]))
        self.assertEqual([2, {"People": [3]}], resolve_folder_path(result["folders"], ["Blogs", "Links"]))

    def test_move_endpoint_uses_both_path_arrays(self):
        request = self.request(
            {
                "feed_id": "2",
                "in_folders": "Links",
                "to_folders": "Links",
                "in_folder_paths": '[["Blogs","Links"]]',
                "to_folder_paths": '[["Art","Links"]]',
            }
        )
        with patch.object(views, "get_object_or_404", return_value=self.folders), patch.object(
            views.redis, "Redis"
        ):
            result = json.loads(views.move_feed_to_folders(request).content)
        self.assertEqual(1, result["code"])
        self.assertEqual([4, 2], resolve_folder_path(result["folders"], ["Art", "Links"]))

    def test_add_feed_endpoint_passes_validated_path_to_subscription(self):
        request = self.request(
            {"url": "https://example.com/rss", "folder": "Links", "folder_path": '["Art","Links"]'}
        )
        with patch.object(
            UserSubscriptionFolders.objects, "get_or_create", return_value=(self.folders, False)
        ), patch.object(views, "validate_public_url"), patch.object(
            views.UserSubscription, "add_subscription", return_value=(1, "", None)
        ) as add:
            result = json.loads(views.add_url(request).content)
        self.assertEqual(1, result["code"])
        self.assertEqual(["Art", "Links"], add.call_args.kwargs["folder"])

    def test_invalid_path_returns_api_error_without_mutation(self):
        request = self.request({"folder": "Friends", "parent_folder_path": '["Missing","Links"]'})
        with patch.object(
            UserSubscriptionFolders.objects, "get_or_create", return_value=(self.folders, False)
        ):
            response = views.add_folder(request)
        self.assertEqual(200, response.status_code)
        self.assertEqual(-1, json.loads(response.content)["code"])
        self.save.assert_not_called()
