# Recursive Android folders

Validated on the existing Pixel 5 API 35 emulator with `samuel`, preserving its login and cached stories. The booted iPhone 17e with the same account supplied the iOS reference. No production subscriptions or folders were added, moved, renamed, or deleted during UI verification.

## Runtime checks

- `Blogs → Link Blogs` renders as a nested folder; its feeds indent another level.
- Collapsing Blogs hides its entire subtree. Reopening it preserves Link Blogs' own collapsed state. See `child-state-preserved.png` and `expand-collapse.mp4`.
- Feed lists and destination pickers checked in light, dark, black, and sepia. The `android-*.png` files show lists, and `parent-picker-*.png` show the destination hierarchy before the subsequent Add site sheet redesign.
- Pickers include empty and collapsed folders. Selecting Link Blogs retains `Blogs ▸ Link Blogs` as the destination (`selected-parent.png`). `add-feed-picker.png` records the earlier add-feed picker before the unified sheet replacement.
- The Samsung SM-S901U1 accepted an NB Alpha install over wireless ADB. Its lock screen prevented visual verification at that point; the Play Store package was preserved.

## Automated checks

Before the Add site redesign, both Debug and Alpha passed 367 unit tests each. New coverage exercises recursive parsing, three levels of nesting, duplicate leaf names under different parents, subtree counts, filtering ancestors, and preservation of child collapse state.

Backend path tests: 15 passing. Legacy folder mutation regression tests: 5 passing. Mutations use fixtures or mocked persistence, not Samuel's production account.

## Server compatibility

The new explicit folder-path API support is committed but has not been deployed. Android uses legacy leaf-name requests for uniquely named destinations on the existing server and refuses ambiguous duplicate names rather than selecting the wrong branch. Once the server advertises `folder_paths_supported`, Android sends complete component arrays for add, rename, delete, and move operations.

## Capture environment

The software-rendered emulator became unresponsive and produced SystemUI/input timeouts. Restarting the same AVD with host graphics and two CPU cores restored responsive input while preserving app data. The expand/collapse video is visual evidence, not an FPS benchmark: Android screenrecord omits idle frames. No scrolling speed claim is derived from that recording.
