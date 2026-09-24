# Feed filters and story menu device validation

Follow-up work on `android-add-discover-sites`, after the Android 15.0.2 Play submission. These changes are installed as a debug build on the attached Samsung SM-S901U1 running Android 16. They are not part of the already uploaded 15.0.2 bundle; no release tag was moved and no replacement Play release was submitted.

## Changes

- `9a26a7d87`: All remains visible. Unread, Focus, and Saved all display labels when space permits; compact layouts retain the active label. Removed weights and layout animations that squeezed labels or left empty highlights.
- `fea045aba`: Story long press opens an anchored, rounded popover. Every action has an icon. Dividers separate read actions, saving, sharing, and feed tools. The navigation action says **Open feed**. The existing action callbacks, scope rules, and sort-dependent range order remain in use. Oldest sorting also retains the intelligence trainer.
- `192fbaf82`: Center each filter's contents in its minimum touch target, including the pressed state of an icon-only button. Captured the asymmetric Focus highlight before fixing it.

## Checks

- Both label and horizontal-centering regressions failed before their fixes. Final unit suite: **514 tests, zero failures/errors/skips**. `:app:assembleDebug` passed using Android Studio's JBR.
- Reused the Samsung and its login. No instrumentation APK or account reset.
- Checked feed labels and story menus in **light, dark, black, and sepia**, in portrait and landscape. Portrait retains All plus the selected filter; landscape restores all four labels. Exercised All, Unread, Focus, and Saved selection.
- Held Focus down while Unread remained selected and captured the symmetric pressed highlight in all four themes after the final fix.
- Verified older and newer read confirmations through the new popover, then canceled both without executing bulk read actions.
- Scrolled the short landscape menu to verify Share, Open feed, and Intelligence trainer remain reachable.
- Checked the filter bar and story menu with Android font scale **1.5**. This was focused component coverage, not a full large-text audit of the app.
- Restored original Auto theme, long-press preference, range-confirmation preference, mark-read-on-scroll preference, font scale 1.0, and automatic rotation. Left the updated app on the feed list. No crash entries appeared in the device crash buffer during this validation window.

[Screenshots](screenshots/) show the pressed-state regression and fix, all menu themes, landscape labels and menu scrolling, read-range confirmations, large-text layouts, and the final feed list.
