# Android 16.0.4

Version 16.0.4, code 296 includes the approved Play crash fixes from PR #2178,
merged at `e8208a8e47c71cc789bc8d90a7c17a048775f02e`, plus the tablet fixes and
F-Droid source separation from 16.0.2 and 16.0.3. The release source is
`1b32c5b65bdf577402c055d34246691d53e534d9`.

All 890 Play-build unit tests passed with no failures, errors, or skips. The
release bundle builds successfully, its archive integrity passes, and the
embedded manifest reports 16.0.4 (296). Signing and Play binary upload are pending
the configured upload-key password; the current bundle is unsigned.

English listing and subscription copy were refreshed, then translated and
independently reviewed across all 21 app languages. All 336 Android text fields
pass validation. The 21 listings are staged in an uncommitted Play edit and read
back successfully. Both subscriptions' text updates are applied and read back in
all 21 locales, with pricing, offers, billing configuration, and product IDs
verified unchanged. Release notes are prepared for all 21 supported Play locales.
No artwork or video changes are included.

The production baseline is 16.0.2 (294), fully rolled out, with managed publishing
off and no pending changes. The intended rollout for 16.0.4 is full production.
No 16.0.4 Play release has been submitted yet.

The GitHub release workflow is validating the exact source before publishing its
immutable `Android_16.0.4` tag. The external F-Droid metadata recipe is prepared;
see `fdroid-status.md` for the separate submission and official publication status.

Canonical translations are under `clients/store/`; native Play notes and the
validated Google upload payload are retained here. `proof/` records the baseline,
independent reviews, local test/build checks, and store read-backs. The store export
tool now supports Android-only release notes without requiring an iOS release.
