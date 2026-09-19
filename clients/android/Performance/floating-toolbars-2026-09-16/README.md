# Floating Android toolbars

Branch: `android-add-discover-sites`. Main implementation commits: `a00440837`, `95b29ee54`, `dbe9e059e`, `e70111ed4`.

The story toolbar defaults to Bottom. Preferences → Story Layout → Story list toolbar position offers Top and Bottom, using the same `story_toolbar_position` key as iOS. Top retains the existing story header. Bottom groups Related Sites, filter/order, and Search on the left, with the compound cutoff/mark-read control on the right. Narrow windows merge the capsules; wider windows restore labels in the iOS priority order. Search sits above the controls and both move above the keyboard.

In Bottom mode, story titles extend to the physical screen bottom behind the transparent footer. Only the capsules and search field have a background. Navigation and keyboard insets position those controls independently of the list viewport; unclipped list padding lets the final story scroll above them. The next-feed control also stays above the floating controls.

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

## September 17: transparent story footer correction

Implementation: `1948671dc`. The list previously stopped at pixel 2115 on the physical phone, above the floating footer. It now extends to the screen bottom at pixel 2340. The footer overlays the list, and unclipped end padding lets the last story scroll clear of its controls. Top mode retains its previous layout.

The device regression in `test_footer_overlay.rb` failed before the fix and passed afterward in all eight light/dark/black/sepia and portrait/landscape combinations. Run it with a story list open, Bottom selected, and the keyboard closed:

```sh
ruby clients/android/Performance/floating-toolbars-2026-09-16/test_footer_overlay.rb DEVICE_SERIAL
```

The corrected APK built and all 20 focused toolbar, story-header, and inset tests passed. Physical checks also covered landscape keyboard search, the anchored cutoff popover, scrolling the final story above the controls, and the preserved Top layout. Screenshots are in `footer-overlay/`, including the original failing layout and restored Auto theme. Auto theme, Bottom placement, mark-read-on-scroll, and automatic rotation were restored; the final device regression passed again.
