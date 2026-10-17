# Localized store copy

`metadata/<language>.json` holds the current App Store and Google Play listing text. `releases/<version>/<language>.json` holds only iOS `whats_new` and Android `release_notes`. `products/<language>.json` holds localized subscription and subscription-group text; the English file defines the inventoried product IDs. Each directory must cover exactly the languages in `localization/languages.json`. `locales.json` maps those language identifiers to the stores' supported locale codes and records the source references.

For each release, rewrite the English listing, release notes, and product copy first. Translate all supported languages in parallel using `localization/glossaries/`, then have different agents review the translations against English. Preserve NewsBlur, actual feature availability, account qualifications, subscription disclosures, and the terms/privacy URLs. Adapt short fields naturally; never truncate text to pass a limit. Inventory live subscriptions and groups before changing the English product IDs. Storefront screenshots are separate assets and are not translated by these scripts.

Validate and export with Ruby's standard library:

```sh
ruby clients/store/validate.rb 16.0
ruby clients/store/export.rb 16.0 --output /tmp/newsblur-store-16.0
```

For a release on one platform, select it explicitly:

```sh
ruby clients/store/validate.rb 16.0.4 --platform android
ruby clients/store/export.rb 16.0.4 --platform android --output /tmp/newsblur-store-16.0.4
```

`--platform ios` selects Apple instead. The default, `both`, still requires and exports both platforms. A selected platform must have complete text for every app language; shared files may retain the other platform's content, which is ignored. Unknown platform keys are rejected. A single-platform export writes only that store's directory and `validation.json`. Run `ruby clients/store/test_platform_export.rb` for the export regression tests.

The exporter validates all inputs before writing and requires a new output directory. `--store-dir` and `--languages` support isolated fixtures. Validation checks exact language, field, and product coverage, nonempty text, store length limits, keywords in UTF-8 bytes, forbidden control characters, the brand, and canonical description URLs. Product benefits must match the English count, with at most four benefits of 40 characters each. It does not prove translation quality or replace independent review.

Apple auto-renewable subscription names allow 35 characters and descriptions allow 55, matching the [product-page guide](https://developer.apple.com/app-store/product-page/) and the live App Store Connect forms checked on 2026-10-16. The [In-App Purchase reference](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information/) still lists 30/45; do not apply those stricter values to the observed subscription fields. Subscription-group display names allow 35 characters and custom app names allow 30 in the live forms. Group display names are customer-facing, separate from internal reference names. `locales.json` records these limits and their provenance; recheck the actual fields when Apple changes them.

Exports:

- `google/listings.json`: API Listing objects with `language`, `title`, `shortDescription`, and `fullDescription`.
- `google/release-notes.json`: `{language, text}` entries for a track release's `releaseNotes` field.
- `google/release-notes.txt`: Play Console release notes enclosed in full store-locale tags, including region codes where required.
- `apple/app-info-localizations.json`: JSON API payloads for localized name and subtitle.
- `apple/version-localizations.json`: JSON API payloads for description, keywords, promotional text, and What's New.
- `apple/subscription-localizations.json`: product IDs and their localized subscription name/description payloads.
- `apple/subscription-group-localizations.json`: group localization payloads with live group ID relationships.
- `google/subscriptions.json`: product IDs and localized subscription listings, including benefits.
- `validation.json`: field lengths and limits for the exported version.

Apple create requests also need parent relationships. Supply `--app-info-id ID` and `--app-store-version-id ID` to add them for app/version localizations. Resolve each subscription's product ID to its live numeric resource ID and add its subscription relationship. For an existing localization, the uploader must use its live resource ID and the supported PATCH attributes rather than POSTing another locale; omit create-only locale and relationship fields. Preserve existing privacy, marketing, and support URLs. For a missing locale, copy the correct shared URLs from the current listing if no localized destination exists.

Google listing updates must preserve any existing video. Track updates must preserve version codes, release status, and unrelated releases. Subscription updates must merge the localized listings and preserve base plans, prices, offers, and other live configuration. Inventory and preserve existing regional locales beyond the canonical set. These files contain text payloads only; they neither upload nor submit a release. Use the release skills to update the stores, fetch every field back, compare it with the export, and record submission and publication separately.
