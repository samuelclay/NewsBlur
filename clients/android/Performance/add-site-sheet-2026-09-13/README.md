# Android Add site sheet validation

Validated on the existing Pixel 5 API 35 emulator (1080 × 2340, font scale 1.0), signed in as samuel. The production account was used for search and folder selection only; no subscriptions or folders were added, moved, or deleted.

## UI coverage

- Light, dark, black, and sepia: compact empty sheet, live search/loading, populated results, inline new-folder field, and recursive folder menu.
- `light-typing.png` captures the search spinner with the keyboard visible.
- `sepia-folders.png` captures the final rounded folder menu with normal-weight labels and recursive indentation.
- `sepia-selected-folder.png` captures the settled `Blogs ▸ Link Blogs` selection and new-folder field. Other `*-selected-folder.png` images capture the menu closing after selection.
- Results include full feed URLs, comma-formatted subscriber counts, and fresh/stale story dates from the full autocomplete response.
- `move-folder-picker.png` confirms recursive indentation also reaches the existing Choose folders dialog. The dialog was canceled without saving, and the temporary long-press preference was restored.
- `scroll-and-dismiss.mp4` records scrolling back toward the top followed by sheet dismissal and an outside-tap dismissal.

## Downward scroll regression

Before the fix, dragging downward through a scrolled results list lowered the native bottom sheet. After release, the sheet returned to its original position but the results had not scrolled. `scroll-before.txt` records the failing real-input regression; the matching screenshots show unchanged result positions.

`AddSiteSheet.kt` now connects its Compose LazyColumn to the native bottom sheet's nested scrolling. The same gesture moves the results while keeping the header at the same bounds. `scroll-after.txt` records the passing replay; the after screenshots show changed result positions with the same header position. Repeated downward drags reach the list top and then dismiss the sheet. Tapping outside also dismisses it.

To replay on the configured emulator, open Add site, search `kottke`, hide the keyboard, and leave the new-folder input closed:

```sh
ruby clients/android/Performance/add-site-sheet-2026-09-13/scroll-regression.rb after
```

The script only scrolls and captures screenshots. It does not submit a result or change the account.

## Automated checks

- Debug unit tests: 377 passed, zero failures/errors/skips.
- Alpha unit tests: 377 passed, zero failures/errors/skips.
- Both final Debug and Alpha APKs build successfully.
- Focused ktlint checks pass for Add site Kotlin sources and compatibility hosts.
- Ten new unit tests cover debounce/clearing, stale response ordering, network failure, duplicate-submit prevention, retry after folder creation, folder-only creation, full autocomplete payloads, and freshness formatting.

The redesigned sheet was installed on the Samsung S22 NB Alpha app before the scrolling report. The final nested-scrolling fix is installed and verified on the emulator; the Samsung disconnected before the final reinstall. Its production NewsBlur package was not replaced.
