# Android 16.0.6 (298)

Submitted to Google Play production on October 27, 2026 at 100% rollout. The signed-in Console shows **Changes in review**, with automated quick checks running and managed publishing off. Approval and public availability have not been verified. Before this submission, 16.0.5 (297) was the latest publicly available production release.

## Fix

Marking a feed read could send NewsBlur to the background on tablets when the feed pane was already open. Both the bottom button and the red feed-menu action called `ItemsList.onReadingActionCompleted()`, which reused explicit Back navigation and reached `moveTaskToBack(true)`. Completion now opens or focuses the feed pane directly. Existing next-feed sessions, phone navigation, and explicit Back behavior are preserved.

- Fix: `727f44a7b88d36f33696e570e057f44a8c9708d5`.
- Version/source: `1484f00b7399cf1696d0a74254046b9d0bfb6d0c`.
- Release tag: `Android_16.0.6`, at the exact version/source commit; see `proof/source-ci.json`.
- AAB SHA-256: `8ce2684d0e7bade498ee65a719c8d0d7b39b4a52aebcef7244ca5a2e424ba3c1`.

## Verification

The original behavior was reproduced on the connected Samsung Galaxy Tab A8 (SM-X200, Android 14) using 16.0.5 debug source. Both actions backgrounded the app; its PID remained alive and there was no new AndroidRuntime exception. This reproduces the reported symptom, but the customer's Lenovo tablet and missing email log attachment were unavailable.

A regression test failed before the fix. The five new navigation tests and related suites passed (32 focused tests), and the full signed build passed 914 unit tests with zero failures, errors, or skips. The fix was manually verified on the Samsung tablet in light, dark, black, and sepia themes, covering both mark-read controls. These runtime checks used the fixed source before the version-only bump. Debug 16.0.6 was subsequently installed on the tablet and S22 without clearing app data. The S22 remained locked, so no phone UI verification is claimed.

The AAB passed ZIP, embedded manifest/version, and upload certificate checks. Play readback reports the same versionCode and SHA-256. Play's release preview reported no lost supported devices and one nonblocking warning about missing native debug symbols; the ReTrace mapping is attached.

## Store text and submission

English Android store copy was refreshed, then translated and independently cross-reviewed in parallel for all 21 app-supported languages. All 21 have supported Play destinations. Canonical metadata, both subscription products, and release notes were validated and read back exactly. Subscription billing configuration, unrelated tracks, app details, and one-time products were preserved.

The Publisher API accepted staging and upload but returned HTTP 403 when validating the production update. The authenticated Console saved the listings and uploaded the exact signed AAB, then submitted 43 changes (42 listing-field changes plus the production release). The API staging files are intermediate evidence, not submission proof. `proof/play-console-submitted.txt` is the authoritative submission readback. `proof/play-after-submission.json` and `proof/final-readback-validation.json` verify the saved track, locale text, and unchanged unrelated fields. API track status `completed` represents the requested full rollout and does not establish public availability while Console review is pending.

The signed AAB, mapping, and runtime screenshots are archived in iCloud Drive under `NewsBlur/Android/Builds/16.0.6/`. Later store/evidence commits do not change or move the release tag.
