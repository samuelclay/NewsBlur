"""Failure and recovery checks for google_play_assets.py's asset-only mutations."""

import copy
import json
import unittest
from unittest.mock import Mock, patch

from google_play_assets import assert_preserved, image_list, stage, stage_group, verify


class Test_GooglePlayAssets(unittest.TestCase):
    def setUp(self):
        self.key = "en-US/phoneScreenshots"
        self.old = [{"id": "old", "sha256": "old-hash"}]
        self.rows = [{"position": 1, "sha256": "first"}, {"position": 2, "sha256": "second"}]
        self.checkpoint = {"groups": {}, "videos": {}}
        self.save = Mock()
        self.api = Mock()
        self.images = self.api.edits.return_value.images.return_value
        self.remote = copy.deepcopy(self.old)
        self.images.list.return_value.execute.side_effect = lambda **kwargs: {
            "images": copy.deepcopy(self.remote)
        }
        self.images.deleteall.return_value.execute.side_effect = lambda: self.remote.clear()

    def test_image_inventory_retries_transient_http_failure(self):
        from googleapiclient.http import HttpRequest
        from httplib2 import Response

        transport = Mock()
        transport.request.side_effect = [
            (Response({"status": "503"}), b'{"error":{"message":"Unavailable"}}'),
            (Response({"status": "200"}), b'{"images":[{"id":"saved","sha256":"exact"}]}'),
        ]
        request = HttpRequest(
            transport, lambda response, content: json.loads(content), "https://example.test"
        )
        request._sleep = Mock()
        self.images.list.return_value = request
        self.assertEqual(image_list(self.api, "edit", self.key), [{"id": "saved", "sha256": "exact"}])
        self.assertEqual(transport.request.call_count, 2)

    def test_image_inventory_does_not_retry_permission_failure(self):
        from googleapiclient.errors import HttpError
        from googleapiclient.http import HttpRequest
        from httplib2 import Response

        transport = Mock()
        transport.request.return_value = (
            Response({"status": "403"}),
            b'{"error":{"message":"Permission denied","errors":[{"reason":"forbidden"}]}}',
        )
        request = HttpRequest(
            transport, lambda response, content: json.loads(content), "https://example.test"
        )
        request._sleep = Mock()
        self.images.list.return_value = request
        with self.assertRaises(HttpError):
            image_list(self.api, "edit", self.key)
        self.assertEqual(transport.request.call_count, 1)

    def upload(self, api, edit_id, key, row):
        self.remote.append({"id": str(row["position"]), "sha256": row["sha256"]})

    def run_group(self, upload=None):
        stage_group(
            self.api, "edit", self.key, self.rows, self.old, self.checkpoint, self.save, upload or self.upload
        )

    def baseline(self):
        return {
            "packageName": "com.newsblur",
            "edit": {"id": "edit"},
            "listings": [
                {
                    "language": "en-US",
                    "title": "NewsBlur",
                    "video": "old",
                    "fullDescription": "Keep this text",
                }
            ],
            "tracks": [
                {"track": "production", "releases": [{"versionCodes": ["292"], "status": "completed"}]}
            ],
            "details": {"defaultLanguage": "en-US"},
            "images": {
                self.key: self.old,
                "en-US/featureGraphic": [{"id": "feature", "sha256": "feature-hash"}],
            },
        }

    def test_lost_upload_response_resumes_without_duplicate_or_second_clear(self):
        def interrupted_upload(*args):
            self.upload(*args)
            raise TimeoutError("Response lost after server accepted image")

        with self.assertRaises(TimeoutError):
            self.run_group(interrupted_upload)
        self.run_group()
        self.assertEqual(["first", "second"], [image["sha256"] for image in self.remote])
        self.images.deleteall.assert_called_once()
        self.assertEqual("verified", self.checkpoint["groups"][self.key])

    def test_lost_delete_response_recovers_empty_set(self):
        def interrupted_delete():
            self.remote.clear()
            raise TimeoutError("Response lost after server cleared images")

        self.images.deleteall.return_value.execute.side_effect = interrupted_delete
        with self.assertRaises(TimeoutError):
            self.run_group()
        self.assertEqual("clearing", self.checkpoint["groups"][self.key])
        self.run_group()
        self.images.deleteall.assert_called_once()
        self.assertEqual(2, len(self.remote))

    def test_unexpected_image_blocks_deletion(self):
        self.remote.append({"id": "foreign", "sha256": "unexpected"})
        with self.assertRaisesRegex(ValueError, "changed since baseline"):
            self.run_group()
        self.images.deleteall.assert_not_called()

    def test_changed_resume_prefix_blocks_further_upload(self):
        self.checkpoint["groups"][self.key] = "uploading"
        self.remote = [{"id": "foreign", "sha256": "unexpected"}]
        upload = Mock()
        with self.assertRaisesRegex(ValueError, "Unexpected upload prefix"):
            self.run_group(upload)
        upload.assert_not_called()
        self.images.deleteall.assert_not_called()

    def test_unrelated_text_track_or_image_changes_fail_preservation(self):
        before = self.baseline()
        for field in ["listings", "tracks", "images"]:
            with self.subTest(field=field):
                actual = copy.deepcopy(before)
                if field == "listings":
                    actual[field][0]["title"] = "Someone else's text"
                elif field == "tracks":
                    actual[field][0]["releases"][0]["versionCodes"] = ["293"]
                else:
                    actual[field]["en-US/featureGraphic"] = []
                with self.assertRaises(ValueError):
                    assert_preserved(actual, before, {self.key: self.rows}, {})

    def test_readback_rejects_reordered_images(self):
        before = self.baseline()
        actual = copy.deepcopy(before)
        actual["images"][self.key] = [{"id": "2", "sha256": "second"}, {"id": "1", "sha256": "first"}]
        with patch("google_play_assets.snapshot", return_value=actual):
            with self.assertRaisesRegex(ValueError, "count, order or checksum"):
                verify(self.api, "edit", before, {self.key: self.rows}, {})

    def test_foreign_change_in_later_group_blocks_all_mutations(self):
        before = self.baseline()
        other = "en-US/tenInchScreenshots"
        before["images"][other] = []
        current = copy.deepcopy(before)
        current["images"][other] = [{"id": "new", "sha256": "someone-elses-image"}]
        with patch("google_play_assets.snapshot", return_value=current):
            with self.assertRaisesRegex(ValueError, "changed since baseline"):
                stage(
                    self.api,
                    "edit",
                    before,
                    {self.key: self.rows, other: self.rows},
                    {},
                    self.checkpoint,
                    self.save,
                )
        self.images.deleteall.assert_not_called()
        self.images.upload.assert_not_called()

    def test_video_update_preserves_all_other_listing_fields(self):
        before = self.baseline()
        desired = {**before["listings"][0], "video": "https://www.youtube.com/watch?v=12345678901"}
        listings = self.api.edits.return_value.listings.return_value
        listings.get.return_value.execute.side_effect = [before["listings"][0], desired]
        after = copy.deepcopy(before)
        after["listings"] = [desired]
        with patch("google_play_assets.snapshot", side_effect=[before, after]):
            stage(
                self.api, "edit", before, {}, {"en-US": {"url": desired["video"]}}, self.checkpoint, self.save
            )
        self.assertEqual(desired, listings.update.call_args.kwargs["body"])
        self.images.deleteall.assert_not_called()
        self.api.edits.return_value.tracks.return_value.update.assert_not_called()


if __name__ == "__main__":
    unittest.main()
