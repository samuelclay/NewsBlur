# Floating Android toolbars

Branch: `android-add-discover-sites`. Main implementation commits: `a00440837`, `95b29ee54`, `dbe9e059e`, `e70111ed4`.

The story toolbar defaults to Bottom. Preferences → Story Layout → Story list toolbar position offers Top and Bottom, using the same `story_toolbar_position` key as iOS. Top retains the existing story header. Bottom groups Related Sites, filter/order, and Search on the left, with the compound cutoff/mark-read control on the right. Narrow windows merge the capsules; wider windows restore labels in the iOS priority order. Search sits above the controls and both move above the keyboard.

The main feed list uses one floating capsule with Add on the left, All/Unread/Focus/Saved in the middle, and Settings on the right. Labels collapse together when space is constrained. Feed rows scroll behind the capsule, with bottom padding to make the last row reachable.

Menus use anchored Android popovers with an eight-dp gap, preserving the source button. Tall menus scroll within the available space. Related Sites uses the existing discovery cards and Try/Add actions. Colors come from the shared theme palette. Android uses translucent rounded surfaces and elevation; Apple's glass material is not available on Android.

References checked directly in the `ios-add-discover-sites` worktree: `StoryTitlesHeaderBar.swift`, `FeedsObjCViewController.m`, and `PreferencesView.swift`.

## Automated validation

The debug APK builds successfully. All 44 focused tests pass: six new toolbar fitting/popover geometry tests, 24 discovery tests, 12 existing story-header tests, and two inset utility tests. Scoped Kotlin formatting and `git diff --check` pass.

```sh
env JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew \
  :app:assembleDebug :app:testDebugUnitTest \
  --tests 'com.newsblur.toolbar.*' --tests 'com.newsblur.discover.*' --tests '*StoryHeader*' --tests '*EdgeToEdgeUtilTest'
```

## Physical device validation

Samsung SM-S901U1, Android 16. Installed with `adb install -r`, preserving login; no instrumentation APK used.

- Changed the preference through the actual Settings screen to Top and back to Bottom.
- Search opens the keyboard, finds live iPhone stories, and closes without leaving expanded labels or clipped controls.
- Search retains its query through rotation. On the Samsung landscape keyboard, fullscreen extract editing is disabled and the feed title header temporarily collapses when needed so the search field and action buttons fit above the keyboard. Closing search restores the header. See `search-landscape-final.png`.
- Both mark-read controls reached their expected confirmation dialogs and were canceled. Confirmation preferences were temporarily enabled to avoid changing read state.
- Oldest and Newest actions changed the story ordering, then Newest was restored.
- Related Sites loaded live recommendations in an anchored popover.
- Rotating with Related Sites open dismisses its old popover anchor cleanly.
- Light, dark, black, and sepia: both feed and story lists checked in portrait and landscape, plus scrollable landscape Settings and story-options popovers. The final feed-label measurement change was rechecked in all four themes.
- At density 620 (approximately 279 dp wide), the story toolbar merges into one capsule with all five targets visible. At normal density with font scale 1.3, it keeps readable controls without clipping.
- All, Unread, Focus, and Saved filters respond; Saved Stories omits discovery and mark-read controls. The floating Add button opens Add + Discover Sites.

The device was returned to Auto theme, font scale 1.0, physical density 480, automatic rotation, Unread, and the original mark-read confirmation preferences. Bottom remains selected. No NewsBlur crash appears in the crash buffer; a concurrent UI Automator dump caused a tooling-only accessibility registration exception during the checks.

Screenshots in this directory document the preference, keyboard, popovers, and device layout checks.
