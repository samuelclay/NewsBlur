# Android 15.0.1 open testing release

- Version: `15.0.1` / version code `286`; package: `com.newsblur`.
- Source: `30d3a3270396693314eb436b2660d1d9a2c36ff8` on `android-add-discover-sites`.
- Pushed tag: `Android_15.0.1`. The existing `Android_15.0.0` tag is unchanged.
- Includes Add + Discover Sites, rich discovery story previews, floating feed and story toolbars, Bottom as the default story-toolbar position, and the transparent full-height story-list footer correction.
- [English release notes](en-US.txt): 426 characters excluding the final newline.

## Validation and artifacts

- Built with Android Studio's JBR using `:app:testDebugUnitTest :app:bundleRelease` and the existing release signing configuration.
- All 502 unit tests pass, with zero failures, errors, or skips. Release optimization and lint-vital tasks pass.
- Archive integrity passes and JAR signature verifies. Certificate SHA-256 matches the previous Play bundle: `5C:5E:93:50:3C:6A:C4:89:88:6A:29:BE:0C:28:6B:A6:04:82:E2:C2:5A:A6:D6:EF:56:84:FD:6E:8F:D7:C3:19`.
- Bundle SHA-256: `4580db308db601a13b79e6b11764544a0e36cad328a9ffa6bc026288924102fe`.
- Bundle size: 11,527,069 bytes. ReTrace mapping is embedded in the AAB.
- Bundle, mapping, and notes archived as `NewsBlur-15.0.1.aab`, `NewsBlur-15.0.1-mapping.txt`, and `NewsBlur-15.0.1-testing-notes.txt` in `~/Library/Mobile Documents/com~apple~CloudDocs/NewsBlur/Android/Builds/`.
- [Physical device validation](../../Performance/floating-toolbars-2026-09-16/README.md) covers four themes, portrait/landscape, keyboard search, popovers, Top placement, and full-height story-list scrolling.

## Store submission

Submitted on September 17, 2026 to **Open testing**, at 100% of that track. Play accepted `286 (15.0.1)` with the embedded ReTrace mapping and no loss of supported devices. The sole non-blocking warning recommends native debug symbols.

Verified **Changes in review**, with quick checks still running and managed publishing off. This records submission, not confirmed tester availability. Production was not changed.

- [Publishing overview](https://play.google.com/console/u/3/developers/6280481402178293168/app/4972990522498280751/publishing)
- [Release review](https://play.google.com/console/u/3/developers/6280481402178293168/app/4972990522498280751/tracks/4698162496597079541/releases/99/review)
- [Submission screenshot](play-testing-submitted.png)
