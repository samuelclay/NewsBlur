# Story-title settings menus and combined read mode

Validated on the attached Samsung Galaxy S22 (Android 16). Implementation commits: `91b08626e`, `936a889bd` on `android-add-discover-sites`. Debug APK installed with login preserved. No version bump or new Play submission for these changes.

## Result

The story-title gear previously rendered only feed actions, leaving All Site Stories with a single action. It now includes theme, linked feed/story-list font size, and the shared read-mode selector. Feed and folder actions remain scoped to their respective lists. All Site Stories always confirms Mark all as read, with red icon and text.

The combined mode offers scroll or selection, selection only, 1/2/3/5/10/30/60-second delays, and manual. Preferences and the story menu use the same choices and stored value. Existing 20/45-second settings remain usable and visible when selected. For legacy preferences with both scrolling and an explicit delay/manual choice, the explicit delay/manual choice takes precedence. The previous selection-only default remains unchanged; existing scroll plus immediate becomes scroll or selection.

Feed and story-list sizes continue sharing `list_text_size`; article size remains independent in `default_reading_text_size`. Theme colors use the shared ReaderSheetPalette.

## Automated verification

- Reproduced missing global-menu eligibility with a failing test before fixing it.
- Reproduced missing 1/2/3-second timing values with a failing test before adding them.
- Full `:app:testDebugUnitTest`: **569 passed, 0 failed, 0 skipped**.
- Tests cover menu composition/current selection, legacy mode compatibility, every mode-to-mode preference transition, short reader dwell deadlines, pause/navigation cancellation, manual mode, and mandatory All Site Stories confirmation under every confirmation preference.
- `:app:installDebug` succeeded on the Samsung. No instrumentation tests or app data resets.

## Device verification

- Light, Dark, Black, Sepia: gear and read-mode submenus checked in portrait and landscape. Every read choice remained reachable through submenu scrolling in landscape.
- XXL list size: story list and feed list updated; menu remained scrollable in landscape. Returning to M worked. Article text size stayed at its original 0.9 throughout.
- Selected Manual in the story menu; Preferences displayed Manual. Selected After 2 seconds in Preferences; the story menu displayed its selected checkmark.
- All Site Stories confirmation opened even with the general confirmation preference set to Never. Canceled every confirmation without executing a bulk mark-read action.
- Engadget feed and Art folder gear menus retained their scoped actions alongside all three shared controls.
- Crash buffer contained no NewsBlur crash; it retained an unrelated UiAutomator service-registration failure.
- Restored the original theme plus Auto light/dark variants, list/article sizes, read mode and old scroll flag, confirmation preference, and rotation. Verified restored preference entries against the pre-test snapshot.

## Screenshots

- `before.png`: sparse original gear menu.
- `all-menu-*-portrait.png`: all four themes, including the red bulk action.
- `read-mode-*-landscape-scrolled.png`: final choices and Manual reachable in landscape.
- `read-mode-xxl-landscape.png`: large-font scrollable submenu with gear still visible.
- `font-size-menu.png`, `story-list-xxl-stable.png`, `feed-list-xxl.png`: linked list font controls and result.
- `preferences-combined-mode.png`, `preferences-read-choices.png`, `menu-delay-roundtrip.png`: shared mode preference and persisted selection.
- `mark-all-confirmation-never-preference.png`: mandatory account-wide confirmation.
- `feed-menu.png`, `folder-menu.png`: contextual actions plus shared settings.
