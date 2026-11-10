# Tablet source and resize-control audit

`comparison.json` records the October 17 installed-package and runtime checks. Private Alpha screenshots and APK extracts stay in `/tmp`; they are not marketing assets and are not committed.

The capture package's on-device APK SHA-256 matched the locally built `app-storecapture.apk` exactly. Package Manager reported version 16.0, code 292, installed October 17. The separate Alpha package reported 15.1, code 291, installed October 14.

## Methods

- `adb -s R8YW810E3FF shell pm path PACKAGE` located each installed APK. `sha256sum` on the installed capture APK and `shasum -a 256` on the local APK produced the identical hash recorded in `comparison.json`.
- `adb pull` copied the installed Alpha APK to `/tmp/newsblur-tablet-alpha.apk`. Android SDK `apkanalyzer dex code --class com.newsblur.util.StorySplitView` and `--class com.newsblur.activity.FeedListDrawer` decompiled the installed classes, rather than relying on version labels alone.
- Alpha's `StorySplitView` DEX has `STORY_LIST_SPLIT_RATIO:F = 0.4f`. Its rule builder calls `SplitType.ratio(0.4f)`, then `setSplitType`, `setLayoutDirection(LOCALE)`, and `build`. Its `FeedListDrawer` computes `ceil(windowWidth * 0.4f)` before applying minimum/maximum width constraints. These match the current source methods in `StorySplitView.kt` and `FeedListDrawer.kt`.
- Alpha was launched without reinstalling or clearing data. The language dialog was dismissed with Back. Its native feed drawer and All Site Stories list showed no resize control. A drag across the list/reader boundary from `(768, 600)` to `(1050, 600)` did not change pane width. The reader remained a placeholder; no unread article was opened.
- `wm size` and `wm density` reported physical `1200x1920` and `240`, with no overrides. The tablet was locked in landscape. `dumpsys activity activities` showed a fullscreen Alpha task containing the app's two embedded task fragments, not a Samsung split-screen task shared with another app.

The capture uses the freshly built native release UI. These checks did not reproduce the user's remembered resize handles; they do not claim the user has never seen them in another state. Capture resumed after the coordinator's source/runtime audit, with product UI unchanged. `capture-checkpoint.json` records the temporary pause and progress at that time.
