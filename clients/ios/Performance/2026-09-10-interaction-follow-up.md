# iOS interaction follow-up, September 10, 2026

These changes follow the [original scrolling audit](2026-09-10-audit.md) in the same `ios-scroll-performance` worktree. Validation uses NB Alpha on the existing iPhone 17e simulator, with `samuel` signed in and scroll-to-read enabled. Complete cell visuals are retained. Account recordings remain local under `/tmp/newsblur-scroll-evidence`.

## Parent midpoint

Commit `3fa94262a` marks a story once the top of the visible table crosses halfway through its parent cell, including that cell's image and preview. Match and Related rows do not increase this threshold. Existing cluster preferences still determine whether those children are marked simultaneously.

The test-first checkpoint is `d0d6fe2ec`. Twelve real-table regressions pass, covering different parent heights, child counts, top insets, forward/reverse scrolling, first fast jumps, footers, retained cells, and both cluster preference settings. The clean before failure is `parent-midpoint-red-24.xcresult`; the combined passing list result is `read-and-presentation-after-26.xcresult`.

The real-account recording `parent-midpoint-live-24/scroll.mp4` shows a Techmeme parent and its Wired match. `step2.png` has both unread; `step3.png` has both read while the matched row remains fully visible. This recording uses the final midpoint source with an earlier fade candidate.

## Read fade

Commit `5894f31b4` adds a 0.2-second Core Animation fade to the existing custom cell contents. It preserves the exact final read artwork and uses no row reload or repeated per-frame canvas drawing. Reuse, a changed story identity, and normal read assignments cancel the transition. Offscreen cells and Reduce Motion use the immediate existing appearance.

All 14 fade regressions pass in `read-and-presentation-after-26.xcresult`. They include byte-identical final artwork for 24 combinations of theme, image position, and parent/related row, plus compositor drawing, cancellation, and preference behavior. The clean five-test before failure is recorded in `/tmp/newsblur-read-and-presentation-red-24.log`. The first fade candidate exposed Core Animation's reserved transition-key behavior; the retained code uses `kCATransition` for cancellation.

The inspected `read-fade-final-27/scroll.mp4` shows gradual dimming during slow scrolling followed by 24 seeded fast/reverse gestures. `fade-frames.png` preserves the transition frames. The same capture records 116 cell configurations with 0.221 ms mean, 0.280 ms p95, and 0.475 ms maximum; 6 of 1,305 main-thread intervals exceed the gap threshold, with 102.791 ms excess time and a 51.715 ms worst interval. No full list reload is recorded. A cold preview layout takes 47.221 ms, so this run does not establish that every frame meets its deadline. These are live controls, not an immutable before/after population or GPU FPS measurement.

## Article flash reproduction

`detail-flash-before-24/early.png` and its video show the first destination sliding in blank before its article appears. The warm neighboring article is already drawn during its transition. Three clean regressions in `detail-readiness-red-24.xcresult` reproduce premature exposure, stale readiness, and a real WebKit parser held before article content exists.

An initial preparation candidate moved a child controller's root view outside its parent's hierarchy. The actual first tap rejected that approach with a UIKit hierarchy assertion; evidence is `detail-presentation-candidate-25` and `NB Alpha-2026-09-10-200455.ips` in the local DiagnosticReports directory. That candidate is not a successful after recording. The earlier `read-fade-final-26` recording is also excluded because an unrelated system notification covered the app; `read-fade-final-27` is the valid fade recording.

## Prepared article presentation

Commit `00ed50ba6` prepares an existing page's WKWebView behind the visible app at the destination size, while keeping all controller containment intact. It waits for the current document, bundled fonts, native layout, and saved reading position before promoting that page and starting the native transition. It retains the existing three page controllers and does not wait for remote images to finish. The arbitrary 100 ms reveal timer is removed.

The pending selection tracks the story, collection, fetch request, and source screen. New selections supersede old ones; returning to feeds, explicit Next/Previous, and paging gestures cancel preparation. Normal neighbors are restored before a paging gesture can swap controllers. Failed current navigations release preparation and allow a retry. Filtered collections use visible story locations rather than raw array indexes.

`detail-presentation-after-28/transition-frames.png` shows the real SFist article's complete title and body in the first visible destination frame and throughout the slide. `detail-presentation-warm-28` verifies the correct Hoodline neighbor and return to SFist with complete headers. These contain different stories from the original flash recording, so they demonstrate the rendering behavior rather than a controlled loading-time improvement. Cold document work and remote resources can still take time; the list stays visible while preparation finishes.

The complete Alpha suite passes **291 tests with zero failures in 99.338 seconds**, with `xcodebuild` exiting zero. Evidence is `interaction-full-after-29.xcresult` and `/tmp/newsblur-interaction-full-after-29.log`. Its 56 article cases cover real WebKit paint while an image is held, child-controller containment, safe areas, viewport changes, restored positions, stale callbacks, rapid selections, failures/retries, and Next/swipe cancellation. A synchronous diagnostic test exposed absent storyboard toolbar objects in the isolated navigation fixture; only that unrelated toolbar construction is stubbed, while its real page-swapping and cancellation assertions remain.

The final ordinary app also opens the full Dwell RSS article, switches to extracted Text, and returns to RSS with the correct different image/body content and complete header. The native share sheet opens and is dismissed without sending. Dwell's original website renders in the in-app browser. Evidence is `final-dwell-modes-30`, `final-share-30.png`, and `final-original-30.png`. These functional checks run without performance probes; a concurrent device build means they are not timing comparisons.

The simulator is left signed in as `samuel` at the feed list, with Unread selected and performance probes disabled. Scroll-to-read remains enabled. The inspected final screenshot is `final-simulator-ready-31.png`; no mark-all-as-read action was used.

## Physical device installation

The signed Release build of `00ed50ba6` passes signature verification. Its executable SHA-256 is `7db252d8743c968047df7eb6bd50afafd8ae68dccc582093e4a5245de73232d6`. NB Alpha (`com.newsblur.NB-Alpha`, version 14.7.2, build 336) installs successfully over Wi-Fi on both ClayPhone SE 3 and ClayPad Air. The standard NewsBlur app is not replaced.

ClayPad Air successfully launches the updated app with performance probes disabled. ClayPhone's first launch request is denied because the device is locked, after its installation succeeds. Local install/launch results are `/tmp/newsblur-clayphone-interaction-{install,launch}-30.json` and `/tmp/newsblur-claypad-interaction-{install,launch}-30.json`; the signed build log is `/tmp/newsblur-interaction-device-build-30.log`.

A ClayPhone launch retry at 20:31 is also denied because the phone remains locked (`/tmp/newsblur-clayphone-interaction-launch-31.json`). After the user unlocks the phone, the updated app successfully launches in the foreground with performance probes disabled, PID 41020 (`/tmp/newsblur-clayphone-interaction-launch-32.json`). Installation and foreground launch verification are complete on both devices.

## Preference submenu selection follow-up

The later iPad report of unresponsive mark-read settings reproduces in the shared native menu on the existing simulator. Tapping Only on selection saves the preference but leaves the checkmark beside On scroll or selection. Returning to the parent menu and reopening the submenu reveals the saved selection. Before screenshots are `ipad-settings-selection-before-33.png` and `ipad-settings-persisted-before-33.png`.

Test-first commit `1f5e43ba3` adds six focused regressions. Three fail on the stale selection in `menu-selection-red-35.xcresult`, while persistence, ordinary action menus, and controller release controls pass. Commit `54b945709` updates the checked row and existing visible accessories immediately using a weak submenu reference. It does not reload or close the menu. All six cases pass in `menu-selection-after-36.xcresult`, including all ten timing values and the reader's corresponding timing policy. This follow-up runs the focused suite; the earlier 291-test result remains the preceding full-suite checkpoint.

Live taps verify Only on selection and After 5 seconds, then restore On scroll or selection. Inspected evidence is `menu-selection-after-37.png`, `menu-delay-after-37.png`, and `menu-restored-after-37.png`. The simulator returns to samuel's Unread feed list (`menu-final-feed-list-37.png`).

The signed Release build succeeds and passes signature verification. Executable SHA-256: `463a938d0994dc636a4cfd957b1460cecab88d0a98af35564d472254c3e74591`. The updated NB Alpha installs successfully on ClayPad Air at 21:03; foreground launch is denied because the device is locked. Evidence is `/tmp/newsblur-menu-device-build-37.log` and `/tmp/newsblur-claypad-menu-{install,launch}-37.json`. This menu update has not been installed on ClayPhone.

After the user unlocks ClayPad Air, the updated NB Alpha successfully launches in the foreground with performance probes disabled, PID 1337. The executable matches the new installation path; launch evidence is `/tmp/newsblur-claypad-menu-launch-38.json`.

## Feed unread badges during scrolling

The subsequent iPad report exposes two independent omissions. `FeedsViewController.refreshFeedCounts` refreshes folder/account totals but never updates the existing individual feed cells. Also, `NewsBlurAppDelegate.finishMarkAsRead` returns before notifying the feed list if any article page controller is absent. The same early return affects mark-unread completion.

Test-first commits `0c1a69fee` and `8995839f3` cover real table cells, a real story-model read mutation, absent/partial article controllers, rapid read batches, duplicate and social feeds, saved/search/inactive row semantics, accessibility, and actual badge drawing. The clean seven-case red result is `feed-count-red-40.xcresult`: the model count decreases while its visible badge stays unchanged; absent pages prevent notification. The eighth test verifies rendered artwork rather than scalar state alone.

Commit `81bfb26d3` refreshes only existing visible feed cells whose count or accessibility state changes, reusing the same count configuration as initial rendering. The existing half-second throttle remains. Read completion now notifies the feed list regardless of which article pages exist, and updates whichever pages are present. Mark-unread retains its existing visibility reload. The regression fixture records no feed table reloads, row reloads, new favicon reads, cell replacement, or scroll-offset change for read-count updates.

All eight focused cases pass in `feed-count-after-41.xcresult`. Its retained-cell rendering attachments, exported into `feed-count-render-41`, visibly show the neutral badge changing from 10 to 9 while the focused badge stays at 3. The complete Alpha suite then passes **305 tests, zero failures, in 96.784 seconds**, with `xcodebuild` exiting zero (`feed-count-full-after-42.xcresult`, `/tmp/newsblur-feed-count-full-after-42.log`).

The signed Release build succeeds and passes signature verification (`/tmp/newsblur-feed-count-device-build-43.log`). Its executable SHA-256 is `2a41ea5e53e5b0c8f6b0fedc61dd50284142c7c32f793455a69638c17b163e8b`. This build includes the previous menu, fade, midpoint, and article preparation changes. NB Alpha installs successfully over Wi-Fi on ClayPad Air at 21:39 and ClayPhone SE 3 at 21:42. Both foreground launch requests are denied because the devices are locked. Evidence is `/tmp/newsblur-claypad-feed-count-{install,launch}-43.json` and `/tmp/newsblur-clayphone-feed-count-{install,launch}-43.json`. Physical-device foreground launch and direct sidebar interaction remain unverified for this latest build.

The existing simulator is left at samuel's Unread feed list, with performance probes disabled and scroll-to-read enabled (`feed-count-final-ready-43.png`). The nanobanana feed's original All stories filter remains unchanged. The badge-rendering proof uses isolated UIKit fixtures; the final account screenshot is a launch/state check, not a physical iPad scrolling reproduction. No mark-all-as-read action was used.
