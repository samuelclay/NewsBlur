# Android 15.0.5 production release

- Version: `15.0.5` / version code `290`; package: `com.newsblur`.
- Release commit and pushed tag: `6643deca2939e3870861289a5beb215a88cc1649`, `Android_15.0.5`.
- [Release notes](en-US.txt).

## Validation and artifacts

Built on October 3, 2026 with Android Studio's JBR using `:app:testDebugUnitTest :app:bundleRelease` and the existing release signing credentials. All 720 unit tests in 147 suites passed, with zero failures, errors, or skips. The image-viewer JavaScript tests, R8 optimization, lint-vital, JAR signature verification, and ZIP integrity checks passed. This release preparation did not repeat device UI testing.

The signing certificate SHA-256 matches prior releases: `5C:5E:93:50:3C:6A:C4:89:88:6A:29:BE:0C:28:6B:A6:04:82:E2:C2:5A:A6:D6:EF:56:84:FD:6E:8F:D7:C3:19`.

Bundle SHA-256: `85efe0c0c6b4da4d9240f5c42162b51b0ccb95ae817ad689afac39cbf1b27319`; size: 11,798,141 bytes. ReTrace mapping is embedded. Archived `NewsBlur-15.0.5.aab`, `NewsBlur-15.0.5-mapping.txt`, and `NewsBlur-15.0.5-release-notes.txt` in `~/Library/Mobile Documents/com~apple~CloudDocs/NewsBlur/Android/Builds/`.

## Store submission

Submitted October 3, 2026 through the `conesus@gmail.com` Play Console account to **Production**, with a **100% rollout** across all existing targeted countries. Play accepted `290 (15.0.5)` with ReTrace mapping and no loss of supported devices, including 6,398 tablet models. The only validation warning recommends native debug symbols.

After confirming **Send changes for review**, Play displayed **1 change sent for review** and **Changes in review / Production / 15.0.5 / Start full rollout**. Quick checks were still running and managed publishing was off, allowing automatic publication after approval. This records submission, not Google approval or public availability.

- [Publishing overview](https://play.google.com/console/u/3/developers/6280481402178293168/app/4972990522498280751/publishing)
- [Release review](https://play.google.com/console/u/3/developers/6280481402178293168/app/4972990522498280751/tracks/4699046005160626232/releases/94/review)
