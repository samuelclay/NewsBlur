# Compact Android Add Site sheet

The main plus button previously launched `DiscoverSitesActivity` immediately. It now opens the compact `AddFeedFragment` sheet, following the content in the iOS `ios-add-discover-sites` branch's `AddSiteView.swift` while retaining Android styling.

The sheet contains the URL/search input, folder picker, Add Site and new-folder controls, and Web Feed, Popular, Trending, YouTube, Reddit, Newsletters, Podcasts, and Google News shortcuts. Trending was explicitly requested in addition to the iOS tiles. Typing a query replaces shortcuts with autocomplete results. Choosing a shortcut dismisses the sheet and opens its destination with the chosen folder. Quick Add inside discovery reuses the existing activity.

The content scrolls inside a sheet capped at 55% height in portrait and 85% in landscape. Colors use `ReaderSheetPalette`, including Sepia. The three-column portrait layout adapts to the Samsung's 360dp width.

## Regression and build

`test_add_site_sheet.rb` was written and run on the attached Samsung before implementation. It failed with `plus opened the full discovery activity instead of the compact Add Site sheet`.

Run from the repository root with the feed list open:

```sh
ruby clients/android/Performance/add-site-sheet-2026-09-18/test_add_site_sheet.rb R5CT601C8DA --routes
```

Build and focused tests, from `clients/android/NewsBlur`:

```sh
env JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ANDROID_SERIAL=R5CT601C8DA ./gradlew :app:testDebugUnitTest \
  --tests 'com.newsblur.addsite.*' --tests 'com.newsblur.discover.*' :app:installDebug
```

36 tests passed across 5 suites with no failures, errors, or skips, including new shortcut destination/folder and restoration coverage. Debug build and installation passed. No instrumentation APK was installed.

## Samsung verification

Used the existing Samsung Galaxy S22 (SM-S901U1, Android 16, `R5CT601C8DA`). The previously failing plus-button test passes with the keyboard closed. All eight shortcuts selected their correct full-screen tab, and Android Back returned directly to the feed list. See [validation output](validation.txt).

- Light, dark, black, and sepia: portrait and landscape, including scrolling to the lower tiles without moving the sheet header.
- Chose Absolute Newsletters in the compact folder picker and opened Reddit. The folder and tab survived both rotations. Quick Add inherited the folder, switched to Popular in the existing activity, and one Back returned to feeds.
- Searched `kottke`, observed live autocomplete results, and retained the query through rotation. Input, folder controls, and results remained reachable with the Samsung keyboard open in portrait and landscape.
- Entered an unsubmitted folder draft. Its text and expanded field survived rotation. Focus can return to the URL input on recreation; scrolling or hiding the keyboard reveals the retained folder draft. Focus restoration was not changed in this fix.
- The compact entry test also passed at system font scale 1.3.

No sites or folders were created during these checks. No new entries appeared in the crash buffer. Original Auto theme (Light/Black variants), font scale 1.0, portrait preference, automatic rotation, and default animation setting were restored. The updated debug build remains installed and logged in, with the compact Add Site sheet open. No commits were made.

[Before](screenshots/before-full-discovery.png) · [After](screenshots/final-auto.png) · [All screenshots](screenshots/)
