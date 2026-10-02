# Wide story images

The reported Engadget image had natural dimensions of 780 × 438 in a 393 CSS-pixel WebView. It retained `NB-small-image` because Android's one-time size check ran before the image loaded. Its horizontal bounds were 14–383.09; the new bounds are 0–393.09. Text retains its 12px inset, aspect ratio is preserved, and document width stays 393px.

The implementation uses natural image dimensions to qualify standalone images that can fill the pane without enlargement. CSS uses the current viewport width, with an offset measured from the image's container. This supports nested figures and linked images while leaving captions and text inset. Inline prose images, small assets, short banners, explicit narrow pixel dimensions, protected NewsBlur icons, clipping/floated layouts, lists, tables, and blockquotes remain contained.

Image load/error events update only the affected image. Initial and width-change scans share cached parent classification; height-only changes do not rescan the document. Resize updates also run in hidden preloaded WebViews. No scroll listener or device-width table is needed.

## Verification

- `before.png` and `after-same-story.png` compare the reported article. The latter was captured by applying the candidate assets to the existing page before installation, allowing an exact same-story comparison.
- `before-metrics.json` and `after-metrics.json` record its WebView bounds.
- Debug and Alpha APK builds pass, and the JavaScript packaged in both APKs matches the source checksum.
- Installed the Debug APK on the existing emulator with Samuel's session preserved.
- `*-installed.png` and `*-installed-metrics.json` cover real loaded stories in light, dark, black, and sepia. Each verifies both image edges and absence of horizontal overflow.
- `check-webview.mjs` runs 27 real WebView layout checks using the shipped reader assets in an isolated iframe. It covers cached and delayed loads, linked/nested images, preserved classes/caption margins, portrait aspect ratio, protected/small/inline images, excluded containers, explicit narrow sizes, repeated initialization, and 393→700→393px resizing while hidden. Results are in `layout-checks.txt`.

To rerun the fixture, open a story in the debug app, forward its `webview_devtools_remote_<pid>` ADB socket to local port 9223, and run `node clients/android/Performance/full-bleed-2026-09-13/check-webview.mjs`. The fixture removes itself afterward and does not change account data.

Final source asset SHA-1: `3e434faa152d4f0ce338d8261e99cb47f1fed653`, verified in both APKs. The final clipping safeguard was rebuilt and reinstalled, then checked again in light mode. The emulator was returned to the light theme shown in the original report.
