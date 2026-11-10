# Android 16.0.1

Restores the tablet controls recovered from ClayBook M4's unpublished October 12 commits:

- `e287b420d6acaf2c1ca8b76eaefe30b90c5681f6`: separate fullscreen choices for the feed list and story titles.
- `7adec3eed7e9119ddc3fcbaac4539b68fa382863`: persistent panes with draggable, remembered widths.

The original commits reported version 15.1 but were never included in the shared release history. Integration preserves the 16.0 localization and fixed Next controls, and adapts the recovered pane controls to RTL layouts.

## Release state

Version 16.0 (292) was already available on Google Play. On October 17, its completed rollout was halted through Play Console. Console and Publisher API both confirmed `halted`, with 15.1 (291) serving as the fallback. Existing 16.0 installations are not downgraded. See `proof/play-16.0-halted.png`, its text snapshot, and `proof/play-before.json`.

16.0.1 (293), source tag `Android_16.0.1` at `8eb2afd5698a729f454864e5fbd3efcd5fb3cc58`, was built, signed, and uploaded to a Play draft with all21 release-note locales. It has not been submitted. Physical tablet testing exposed delayed divider dragging, so this artifact must be replaced before submission. See `clients/android/Performance/tablet-controls-recovery-2026-10-17/drag-regression/` for the reproduction and follow-up. Build293 cannot be reused for the corrected upload.

## Localized notes and store assets

All 21 Android release-note translations are in `clients/store/releases/16.0.1/`. This is an Android-only patch release, so those canonical files contain only `android.release_notes`; no iOS release is implied. Matching Play locale exports are beside this README. `release-notes.json` is the Publisher API payload and `release-notes-play.txt` is the Console text.

Two translation batches were independently cross-reviewed. `proof/notes-validation.json` records exact language coverage and lengths. Every note fits Google's 500 Unicode character limit, verified against https://support.google.com/googleplay/android-developer/answer/9859348.

The reviewed 16.0 listing/subscription copy and existing localized images/videos are retained. This patch does not regenerate store artwork or alter product prices, base plans, or entitlements.
