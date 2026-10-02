# Android 15.0.3 open testing release

- Version: `15.0.3` / version code `288`; package: `com.newsblur`.
- Source and pushed tag: `0399ccc7ef6081232f1aedfc8e71b017067ca88e`, `Android_15.0.3`.
- Branch: `android-add-discover-sites`.
- [Release notes](en-US.txt).

## Changes since 15.0.2

Faster native reader entrance with a separate article fade; grouped feed and story popovers with icons and persistent selection highlights; adaptive feed-filter labels and symmetric icon highlights; Open Feed limited to folder reading; blue loading pulses, corrected pagination demand, and the end-of-list flourish; interactive-back and story-selection fixes; actual default font name in reader settings.

## Validation and artifacts

- `:app:testDebugUnitTest :app:bundleRelease` with Android Studio's JBR; release signing applied with the existing local credentials.
- 556 unit tests passed, with zero failures, errors, or skips. Release optimization and lint-vital passed.
- [Samsung reader entrance verification](../../Performance/reader-entry-2026-09-17/README.md) covers four themes, portrait/landscape, early Back, Home/resume, rotation during loading, and Next-story navigation. The version bump adds no behavioral changes to that tested implementation.
- JAR signature and ZIP integrity verified. Signing certificate SHA-256 matches previous releases: `5C:5E:93:50:3C:6A:C4:89:88:6A:29:BE:0C:28:6B:A6:04:82:E2:C2:5A:A6:D6:EF:56:84:FD:6E:8F:D7:C3:19`.
- Bundle SHA-256: `e71e8f16f0b3d099c03c13459cc714790ca991cb36bc3e70786f06a6246a05cc`; size: 11,546,331 bytes. ReTrace mapping is embedded.
- Archived `NewsBlur-15.0.3.aab`, `NewsBlur-15.0.3-mapping.txt`, and `NewsBlur-15.0.3-testing-notes.txt` in `~/Library/Mobile Documents/com~apple~CloudDocs/NewsBlur/Android/Builds/`.

## Store submission

Submitted September 18, 2026 to **Open testing**, at 100% of that track. Play accepted `288 (15.0.3)` with the embedded ReTrace mapping and no loss of supported devices. The only non-blocking warning recommends native debug symbols.

Confirmed the final **Send changes for review** action, then verified **Changes in review** with **Open testing / 15.0.3 / Start full rollout**. Quick checks were still running and managed publishing was off. This records submission, not confirmed availability to testers. Production remains unchanged. The preceding 15.0.2 release was already available to testers when this release was prepared.

- [Publishing overview](https://play.google.com/console/u/3/developers/6280481402178293168/app/4972990522498280751/publishing)
- [Release review](https://play.google.com/console/u/3/developers/6280481402178293168/app/4972990522498280751/tracks/4698162496597079541/releases/101/review)
- [Submission screenshot](play-testing-submitted.png)
