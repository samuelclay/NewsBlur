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
