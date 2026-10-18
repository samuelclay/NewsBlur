"""Regression checks for google_play.py's mutation scope and localization preservation."""

import copy
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock

from google_play import merge_localizations, products_operation, stage_listings, verify_product


class Test_GooglePlayMetadata(unittest.TestCase):
    def test_listing_stage_preserves_video_extra_locale_and_reads_back(self):
        before = [
            {"language": "en-US", "title": "Old", "video": "https://youtu.be/existing"},
            {"language": "en-GB", "title": "Regional title", "video": "https://youtu.be/regional"},
        ]
        requested = [
            {"language": "en-US", "title": "New", "shortDescription": "Short", "fullDescription": "Full"}
        ]
        expected = merge_localizations(before, requested, "language")
        api = Mock()
        listings = api.edits.return_value.listings.return_value
        listings.list.return_value.execute.side_effect = [{"listings": before}, {"listings": expected}]
        listings.get.return_value.execute.return_value = expected[0]
        report = {"completed": []}
        with tempfile.TemporaryDirectory() as folder:
            stage_listings(
                api,
                "edit",
                requested,
                {"edit": {"id": "edit"}, "listings": before},
                report,
                str(Path(folder) / "report.json"),
            )
        body = listings.update.call_args.kwargs["body"]
        self.assertEqual("https://youtu.be/existing", body["video"])
        self.assertEqual(1, listings.update.call_count)
        self.assertEqual(["en-US"], report["completed"])
        listings.get.assert_called_once()

    def test_missing_video_in_listing_readback_stops_staging(self):
        before = [{"language": "en-US", "title": "Old", "video": "https://youtu.be/existing"}]
        requested = [{"language": "en-US", "title": "New"}]
        api = Mock()
        listings = api.edits.return_value.listings.return_value
        listings.list.return_value.execute.return_value = {"listings": before}
        listings.get.return_value.execute.return_value = requested[0]
        with self.assertRaisesRegex(ValueError, "listing.en-US.video"):
            stage_listings(api, "edit", requested, {"edit": {"id": "edit"}, "listings": before}, {}, "unused")

    def test_product_patch_changes_only_listings_and_preserves_extra_locale(self):
        before = {
            "packageName": "com.newsblur",
            "productId": "nb.premium.36",
            "basePlans": [{"basePlanId": "annual", "state": "ACTIVE", "regionalConfigs": [{"price": "36"}]}],
            "listings": [
                {"languageCode": "en-US", "title": "Old", "futureField": "keep"},
                {"languageCode": "en-GB", "title": "Regional title"},
            ],
        }
        product = {"productId": "nb.premium.36", "listings": [{"languageCode": "en-US", "title": "New"}]}
        after = {
            **before,
            "listings": merge_localizations(before["listings"], product["listings"], "languageCode"),
        }
        api = Mock()
        subscriptions = api.monetization.return_value.subscriptions.return_value
        subscriptions.get.return_value.execute.side_effect = [before, after]
        with tempfile.TemporaryDirectory() as folder:
            products_operation(
                api,
                [product],
                {"subscriptions": [before]},
                apply=True,
                regions_version="verified-version",
                report={"completed": []},
                report_path=str(Path(folder) / "report.json"),
            )
        arguments = subscriptions.patch.call_args.kwargs
        self.assertEqual("listings", arguments["updateMask"])
        self.assertFalse(arguments["allowMissing"])
        self.assertEqual({"packageName", "productId", "listings"}, set(arguments["body"]))
        self.assertEqual(after["listings"], arguments["body"]["listings"])
        self.assertEqual("verified-version", arguments["regionsVersion_version"])

    def test_configuration_change_in_product_readback_fails(self):
        before = {"productId": "nb.premium.36", "basePlans": [{"state": "ACTIVE"}], "listings": []}
        after = copy.deepcopy(before)
        after["basePlans"][0]["state"] = "INACTIVE"
        api = Mock()
        api.monetization.return_value.subscriptions.return_value.get.return_value.execute.return_value = after
        with self.assertRaisesRegex(ValueError, "outside localized listings"):
            verify_product(api, {"productId": "nb.premium.36", "listings": []}, before)

    def test_changed_product_baseline_blocks_all_patches(self):
        before = {"productId": "nb.premium.36", "listings": []}
        api = Mock()
        subscriptions = api.monetization.return_value.subscriptions.return_value
        subscriptions.get.return_value.execute.return_value = {**before, "archived": True}
        with self.assertRaisesRegex(ValueError, "changed since baseline"):
            products_operation(api, [before], {"subscriptions": [before]}, apply=True)
        subscriptions.patch.assert_not_called()


if __name__ == "__main__":
    unittest.main()
