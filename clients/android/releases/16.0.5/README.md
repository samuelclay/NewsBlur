# Android 16.0.5

Patch release 16.0.5 (297) contains the 11 crash and freeze fixes documented in
[the October crash audit](../../Performance/play-crash-audit-2026-10-25.md).
The source version-bump commit is `cb80c8f4c7a1c546a08abdac0b066a38627b9567`.

English Android listing and subscription copy were refreshed, translated into
all 21 app languages, and independently reviewed. Release notes describe tablet
startup/navigation, large articles, feed previews, one-feed folders, widgets,
translated comment counts, and startup/sync/billing freezes. Other-platform
metadata remains unchanged. Review hashes and validations are in `proof/`.

Pre-release device smoke tests passed on the Galaxy Tab A8 (Android 14) and Galaxy
S22 (Android 16), preserving login and checking reading/navigation and light,
dark, black, and sepia themes. These are not physical Android 13 Tab S7+ tests.

## Submission

On October 25, 2026, the signed 16.0.5 (297) bundle and 21 localized listings and
release notes were submitted through Play Console for full production rollout.
The Console shows **Changes in review**, with automated quick checks still
running at the recorded observation. Managed publishing is off, so approved
changes publish automatically. Approval and public availability are not yet
verified. The previous public production release was 16.0.4 (296).

The remote `Android_16.0.5` tag points to the exact source commit above. All four
source-commit GitHub workflows passed: Android Tests, Django Tests, Localization,
and Android Release and F-Droid. The latter includes source/dependency scans,
tests, an unsigned F-Droid APK build, and immutable tag publication. This does not
establish publication in the official F-Droid repository.

The local release build passed 909 unit tests with no failures, errors, or skips.
The signed bundle passed ZIP, manifest, and upload-certificate verification.
Its SHA-256 is
`220da212044ceb1c1eec14f111d89e9a7ba3ab77e5477ecf6014c40f309e2814`.
The AAB and R8 mapping are archived in the NewsBlur Android Builds iCloud folder.
Play accepted the same checksum. R8 mapping is embedded; Play's warning about
missing third-party native debug symbols is nonblocking, with zero lost supported
devices.

Post-submission API readback verified all 21 listings, 21 release notes, and 21
locales for each of the two subscription products. There are no unsupported
app locales. Prices, offers, billing configuration, unrelated tracks, app details,
and one-time products remain unchanged. Subscription text updates apply directly;
listing and release changes remain subject to Play review. No custom listings
were present.

The Publisher API accepted staging and upload but denied final release validation
with HTTP 403. The authenticated Console completed the upload and submission;
the failed API edit was never committed. The API's production `completed` status
describes the requested full rollout, not evidence that review has finished.

Evidence is retained in `proof/`, including before/after snapshots, all locale
comparisons, source-commit CI results, build validation, and the Console submission
DOM. Later metadata and evidence commits do not change or move the release tag.
