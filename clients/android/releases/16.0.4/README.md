# Android 16.0.4

Version 16.0.4, code 296 includes the approved Play crash fixes from
[PR #2178](https://github.com/samuelclay/NewsBlur/pull/2178), merged at
`e8208a8e47c71cc789bc8d90a7c17a048775f02e`, plus the tablet fixes and F-Droid
source separation from 16.0.2 and 16.0.3. Release source and immutable tag
`Android_16.0.4` both resolve to `1b32c5b65bdf577402c055d34246691d53e534d9`.
Subsequent store-copy and export-tool commits do not change the Android source.

## Google Play

Submitted on October 17, 2026 for a full production rollout. Publishing overview
shows **Changes in review**, with automated quick checks still running and managed
publishing off. Approval and public availability are not yet verified. The
submission contains release 16.0.4 and 42 listing text changes across 21 locales;
there were no unrelated pending changes. The previous public release was 16.0.2
(294). The preview reports no lost supported devices and one nonblocking warning
about missing native debug symbols. The bundle includes its ReTrace mapping.

English listing and subscription copy were refreshed, translated, and independently
reviewed across all 21 app languages. All 336 Android text fields pass validation.
Post-submission read-back verifies all 21 listings, all 21 release notes, and both
subscriptions in all 21 locales. Pricing, offers, billing configuration, product IDs,
video fields, and other release tracks are verified unchanged. No artwork changes
were made. There are no unsupported app locales.

The Publisher API accepted the bundle and staged text but rejected final edit
validation/commit with HTTP 403. The signed-in Console was used to save and submit
the release and listings. The final saved release and artifact checksum were then
read back through the API; the failed API staging is not the submission evidence.

## Build and F-Droid

All 890 local Play-build unit tests passed with no failures, errors, or skips. The
signed AAB passes ZIP integrity, embedded 16.0.4 (296) manifest, and expected upload
certificate checks. Its SHA-256 is
`17e382f730fd2649e61f10675fceef46d2fc58f9a18d0121ae4ab6258931f99b`, matching the
bundle stored by Play. The AAB and mapping are archived in the iCloud Android Builds
folder. `proof/build-validation.json` records the source and signing evidence.

Android Tests, Django Tests, and Android Release and F-Droid all passed on the exact
release commit. The F-Droid job passed source/dependency scans, unit tests, and the
unsigned APK build before creating the immutable tag. See `proof/github-checks.json`
and `fdroid-status.md` for the separate upstream metadata submission and official
F-Droid publication status. A successful compatibility build is not an official
F-Droid package publication.

Canonical translations are under `clients/store/`; native Play notes and validated
Google payloads are retained here. `proof/` records independent review hashes,
local checks, Console submission evidence, and final read-backs. The export tool
supports Android-only releases and uses adjacent locale tags so Console preserves
release notes exactly; its five regression tests pass with 34 assertions.
