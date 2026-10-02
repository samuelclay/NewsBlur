# Landscape full-bleed regression

The reported Engadget AppleCare image is 780 × 438 pixels. In landscape, the WebView is 803 CSS pixels wide with 12px body gutters. The previous no-enlargement threshold rejected it even though it filled the text column.

Eligibility now permits enlargement across only the body gutters. Nested wrapper widths do not lower this threshold. Smaller images and protected publisher layouts retain the existing safeguards. Text keeps its 12px inset.

- `before.png` and `after-same-story.png` compare the same loaded article with the candidate JavaScript applied to its WebView. Image bounds change from 14–793.27 to 0–803.27; document width remains 803.
- The real WebView regression fixture failed on the 780px image at 803px before this change. All 31 checks now pass, including contained 600px images and portrait/landscape resizing. Results are in `webview-checks.txt`.
- Debug and Alpha APKs build successfully. Packaged JavaScript SHA-1: `8c6f858e5b74d9477b35ff56a823fe8009c5b463`.
- The updated Debug APK was installed on the existing emulator, preserving Samuel's login. Installed landscape screenshots and bounds cover light, dark, black, and sepia. Light was restored afterward.

The same-story comparison also shows a small native pager offset after rotation, separate from the image's CSS gutters. Inspection of ViewPager 1.0.0 found its unfinished-scroll resize target omits page margins; an unchanged-index restore does not correct that target. A freshly opened installed page aligns at native x=0. No native pager change is included here.

This extends the earlier `full-bleed-2026-09-13` evidence; its original no-enlargement description and asset checksum describe the preceding implementation.
