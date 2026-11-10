#!/usr/bin/env python3
"""Upload and read back NewsBlur's exported Google Play text, without publishing releases.

Run google_play.py inside the NewsBlur Docker container. Listing changes remain in
the supplied edit; subscription text updates apply immediately outside that edit.
This CLI cannot create/commit edits, change tracks, upload binaries, or change prices.
"""

import argparse
import copy
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

PACKAGE = "com.newsblur"
ROOT = Path(__file__).resolve().parents[2]


def read_json(path):
    with Path(path).open(encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path, value, *, create=False):
    flags = os.O_WRONLY | os.O_CREAT | (os.O_EXCL if create else os.O_TRUNC)
    descriptor = os.open(path, flags, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def indexed(items, key):
    result = {}
    for item in items:
        identifier = item[key]
        if not identifier or identifier in result:
            raise ValueError(f"Missing or duplicate {key}: {identifier!r}")
        result[identifier] = item
    return result


def merge_localizations(existing, requested, key):
    """google_play.py preserves extra locales and unspecified per-locale fields."""
    result = copy.deepcopy(indexed(existing, key))
    for identifier, item in indexed(requested, key).items():
        result[identifier] = {**result.get(identifier, {}), **item}
    return list(result.values())


def assert_fields(actual, expected, context):
    for key, value in expected.items():
        if actual.get(key) != value:
            raise ValueError(f"Read-back mismatch: {context}.{key}")


def check_text(value, limit, context):
    if not isinstance(value, str) or not value.strip() or len(value) > limit:
        raise ValueError(f"Invalid or over-limit text: {context} (limit {limit})")


def load_export(directory, expected_version):
    directory = Path(directory)
    validation = read_json(directory / "validation.json")
    if validation.get("version") != expected_version:
        raise ValueError("Export version does not match --expected-version")
    mappings = read_json(ROOT / "clients/store/locales.json")["locales"]
    languages = set(read_json(ROOT / "localization/languages.json"))
    if set(validation["languages"]) != languages or len(validation["languages"]) != len(languages):
        raise ValueError("Export does not cover exactly the app-supported languages")
    if {row["language"] for row in mappings} != languages:
        raise ValueError("Store locale mapping does not match app-supported languages")
    locales = {row["google"] for row in mappings}
    if len(locales) != len(languages):
        raise ValueError("Google locale mapping contains duplicate destinations")
    listings = read_json(directory / "google/listings.json")
    if set(indexed(listings, "language")) != locales:
        raise ValueError("Exported Google listings have missing or extra locales")
    for listing in listings:
        if set(listing) != {"language", "title", "shortDescription", "fullDescription"}:
            raise ValueError("Unexpected exported listing fields")
        for field, limit in (("title", 30), ("shortDescription", 80), ("fullDescription", 4000)):
            check_text(listing[field], limit, f"{listing['language']}.{field}")
    products = read_json(directory / "google/subscriptions.json")
    source = read_json(ROOT / "clients/store/products/en.json")["android"]["subscriptions"]
    if set(indexed(products, "productId")) != set(source):
        raise ValueError("Export product IDs differ from the canonical product inventory")
    for product in products:
        if set(product) != {"productId", "listings"}:
            raise ValueError("Export may contain subscription text only")
        if set(indexed(product["listings"], "languageCode")) != locales:
            raise ValueError(f"Missing/extra locales for {product['productId']}")
        for listing in product["listings"]:
            if set(listing) != {"languageCode", "title", "description", "benefits"}:
                raise ValueError("Unexpected exported subscription listing fields")
            check_text(listing["title"], 55, "subscription.title")
            check_text(listing["description"], 200, "subscription.description")
            if not isinstance(listing["benefits"], list) or not 1 <= len(listing["benefits"]) <= 4:
                raise ValueError("Subscription benefits must contain 1 to 4 entries")
            for benefit in listing["benefits"]:
                check_text(benefit, 40, "subscription.benefit")
    return listings, products


def service():
    sys.path.insert(0, str(ROOT))
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "newsblur_web.settings")
    from django.conf import settings
    from google.oauth2.service_account import Credentials
    from googleapiclient.discovery import build

    credentials_info = settings.GOOGLE_PLAY_SERVICE_ACCOUNT_INFO
    if not credentials_info:
        raise ValueError("GOOGLE_PLAY_SERVICE_ACCOUNT_INFO is not configured")
    credentials = Credentials.from_service_account_info(
        credentials_info, scopes=["https://www.googleapis.com/auth/androidpublisher"]
    )
    return build("androidpublisher", "v3", credentials=credentials, cache_discovery=False)


def all_pages(resource, field):
    result = []
    token = None
    seen = set()
    while True:
        arguments = {"packageName": PACKAGE}
        if token:
            arguments["pageToken"] = token
        response = resource.list(**arguments).execute()
        result.extend(response.get(field, []))
        token = response.get("nextPageToken") or response.get("tokenPagination", {}).get("nextPageToken")
        if not token:
            return result
        if token in seen:
            raise ValueError("Google returned a repeated pagination token")
        seen.add(token)


def get_listings(api, edit_id):
    return api.edits().listings().list(packageName=PACKAGE, editId=edit_id).execute().get("listings", [])


def snapshot(api, edit_id):
    edit = api.edits().get(packageName=PACKAGE, editId=edit_id).execute()
    return {
        "packageName": PACKAGE,
        "capturedAt": datetime.now(timezone.utc).isoformat(),
        "edit": edit,
        "listings": get_listings(api, edit_id),
        "tracks": api.edits().tracks().list(packageName=PACKAGE, editId=edit_id).execute().get("tracks", []),
        "details": api.edits().details().get(packageName=PACKAGE, editId=edit_id).execute(),
        "subscriptions": all_pages(api.monetization().subscriptions(), "subscriptions"),
        "oneTimeProducts": all_pages(api.monetization().onetimeproducts(), "oneTimeProducts"),
    }


def read_baseline(path):
    baseline = read_json(path)
    if baseline.get("packageName") != PACKAGE:
        raise ValueError("Baseline package is not NewsBlur")
    return baseline


def verify_listings(api, edit_id, requested, baseline):
    expected = indexed(merge_localizations(baseline["listings"], requested, "language"), "language")
    actual = indexed(get_listings(api, edit_id), "language")
    for locale, listing in expected.items():
        if locale not in actual:
            raise ValueError(f"Missing listing locale: {locale}")
        assert_fields(actual[locale], listing, f"listing.{locale}")
    return {"verifiedLocales": sorted(expected), "requestedLocales": len(requested)}


def stage_listings(api, edit_id, requested, baseline, report, report_path):
    if baseline["edit"]["id"] != edit_id:
        raise ValueError("Staging baseline must describe the supplied edit")
    current = indexed(get_listings(api, edit_id), "language")
    if current != indexed(baseline["listings"], "language"):
        raise ValueError("Listings changed since the baseline; inspect and snapshot again")
    for listing in requested:
        locale = listing["language"]
        desired = {**current.get(locale, {}), **listing}
        api.edits().listings().update(
            packageName=PACKAGE, editId=edit_id, language=locale, body=desired
        ).execute()
        actual = api.edits().listings().get(packageName=PACKAGE, editId=edit_id, language=locale).execute()
        assert_fields(actual, desired, f"listing.{locale}")
        report["completed"].append(locale)
        write_json(report_path, report)
    return verify_listings(api, edit_id, requested, baseline)


def unchanged_product_configuration(before, after):
    before = {key: value for key, value in before.items() if key != "listings"}
    after = {key: value for key, value in after.items() if key != "listings"}
    if before != after:
        raise ValueError("Subscription configuration changed outside localized listings")


def verify_product(api, product, before):
    product_id = product["productId"]
    actual = api.monetization().subscriptions().get(packageName=PACKAGE, productId=product_id).execute()
    unchanged_product_configuration(before, actual)
    expected = merge_localizations(before.get("listings", []), product["listings"], "languageCode")
    actual_locales = indexed(actual.get("listings", []), "languageCode")
    for listing in expected:
        locale = listing["languageCode"]
        if locale not in actual_locales:
            raise ValueError(f"Missing subscription locale: {product_id}.{locale}")
        assert_fields(actual_locales[locale], listing, f"subscription.{product_id}.{locale}")
    return {"productId": product_id, "verifiedLocales": len(expected)}


def products_operation(
    api, products, baseline, *, apply=False, regions_version=None, report=None, report_path=None
):
    previous = indexed(baseline["subscriptions"], "productId")
    resource = api.monetization().subscriptions()
    if apply:
        for product in products:
            product_id = product["productId"]
            before = previous[product_id]
            current = resource.get(packageName=PACKAGE, productId=product_id).execute()
            if current != before:
                raise ValueError(f"Product {product_id} changed since baseline; inspect and snapshot again")
    result = []
    for product in products:
        product_id = product["productId"]
        before = previous[product_id]
        if apply:
            desired = merge_localizations(before.get("listings", []), product["listings"], "languageCode")
            resource.patch(
                packageName=PACKAGE,
                productId=product_id,
                updateMask="listings",
                allowMissing=False,
                body={"packageName": PACKAGE, "productId": product_id, "listings": desired},
                **{"regionsVersion_version": regions_version},
            ).execute()
        result.append(verify_product(api, product, before))
        if apply:
            report["completed"].append(product_id)
            write_json(report_path, report)
    return result


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    commands = result.add_subparsers(dest="command", required=True)
    command = commands.add_parser("snapshot", help="Read existing edit and products; never creates an edit")
    command.add_argument("edit_id")
    command.add_argument("--output", required=True)
    for name in ("stage-listings", "verify-listings", "apply-products", "verify-products"):
        help_text = "Updates LIVE subscription text immediately" if name == "apply-products" else None
        command = commands.add_parser(name, help=help_text)
        command.add_argument("export_directory")
        if name.endswith("listings"):
            command.add_argument("edit_id")
        command.add_argument("--expected-version", required=True)
        command.add_argument(
            "--baseline", required=True, help="Snapshot JSON used to verify preserved fields/locales"
        )
        command.add_argument(
            "--report", required=True, help="New JSON report path; existing paths are refused"
        )
        if name == "apply-products":
            command.add_argument(
                "--regions-version", required=True, help="Current documented Play regions version"
            )
    return result


def main():
    args = parser().parse_args()
    if args.command == "snapshot":
        if Path(args.output).exists():
            raise ValueError("Snapshot output already exists")
        value = snapshot(service(), args.edit_id)
        write_json(args.output, value, create=True)
        print(
            json.dumps(
                {
                    "snapshot": args.output,
                    "listings": len(value["listings"]),
                    "subscriptions": len(value["subscriptions"]),
                    "tracks": len(value["tracks"]),
                }
            )
        )
        return
    listings, products = load_export(args.export_directory, args.expected_version)
    baseline = read_baseline(args.baseline)
    report = {
        "command": args.command,
        "packageName": PACKAGE,
        "version": args.expected_version,
        "baseline": args.baseline,
        "completed": [],
        "status": "started",
    }
    write_json(args.report, report, create=True)
    api = service()
    try:
        if args.command == "stage-listings":
            result = stage_listings(api, args.edit_id, listings, baseline, report, args.report)
        elif args.command == "verify-listings":
            result = verify_listings(api, args.edit_id, listings, baseline)
        else:
            result = products_operation(
                api,
                products,
                baseline,
                apply=args.command == "apply-products",
                regions_version=getattr(args, "regions_version", None),
                report=report,
                report_path=args.report,
            )
        report.update(status="verified", result=result)
    except Exception:
        report["status"] = "failed"
        write_json(args.report, report)
        raise
    write_json(args.report, report)
    print(json.dumps({"status": "verified", "report": args.report, "result": result}))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        print(f"Stopped: {error}", file=sys.stderr)
        sys.exit(1)
