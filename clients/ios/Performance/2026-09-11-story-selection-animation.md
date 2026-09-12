# Story-title selection animation, September 11, 2026

Worktree: `ios-scroll-performance`. NB Alpha only. Changes remain uncommitted.

## Behavior

Selecting an adjacent title in a visible regular-width article pane slides the prepared article into place in 0.28 seconds. A distant selection uses a short directional scan, capped at 0.42 seconds and one already prepared neighboring article. If no neighboring article is ready, it slides directly in 0.34 seconds. The animation follows the user's horizontal or vertical paging preference. Reduce Motion disables spatial movement.

The selected article passes the existing WebKit document, viewport, and restored-position preparation gate before movement starts. The logical pager does not visit the skipped story locations. The existing three article controllers and full cell visuals remain intact.

## Reproduction and cause

The regular iPad title-selection policy disabled animation outside fullscreen. Mac requested animation, but the prepared-document callback promoted the new controller and moved the pager to its final offset with `animated:NO` before the later animated navigation call. That call therefore had no distance left to animate.

The regression observes the outgoing article's Core Animation presentation position on every display refresh. Before the fix, adjacent and 20-story forward/backward selections showed only one or two positions, in both paging orientations. After the initial fix, all six cases passed the requirement for intermediate displayed positions.

Evidence: `/tmp/newsblur-scroll-evidence/title-selection-start-125.png` is the initial simulator setup screenshot. `/tmp/newsblur-scroll-evidence/title-selection-before-127.xcresult` contains the reproduced failures. Runs 125 and 126 were test-fixture compile corrections, not runtime reproductions. Run 127 also exposed a fixture-only automatic-inset mismatch; the fixture now uses `.never`, matching production.

## Additional races found during validation

- A background `refreshPages` during document preparation reset the selected page index and navigated to the prior story. Run 129 reproduces this with two failed assertions.
- A same-hash full-text replacement during movement invalidated document readiness, but animation completion still promoted it. Run 130 reproduces premature presentation and an unready destination.

## Runtime evidence

Run 129 passed rapid reselection, cancellation, resizing, and changed-feed interruption checks. Its real WebKit scan passed with one prepared neighboring article, all 22 other stories (including the 19 intervening stories) still unread, the original reading position retained, and exactly three article controllers. Real rendered article screenshots are attached to the result bundles. These are isolated runtime fixtures; they do not claim a manual account-level Mac interaction test or a measured GPU frame rate.

Run 131 passed the six direction/distance cases, the policy, real scan, refresh regression, and all seven interruption cases (including cancellation and reselection while a replacement is pending). Adjacent selections showed 14–18 distinct presented positions and completed 286–305 ms after the mocked DOM-ready signal. Distant direct selections showed 22–23 positions and completed 355–393 ms after readiness. These timings include preparation callbacks and test scheduling, not just the prescribed animation duration.

Run 132 passed the real WebKit replacement test after correcting the fixture to update the page's mutable story copy. Its parser was deliberately held while the painted destination stayed visible, then released before selection completed. Both the mid-scan and held-replacement screenshots were visually inspected. The recording is `/tmp/newsblur-scroll-evidence/title-selection-video-132/scroll.mp4`; the actual article scan appears near 11.5 seconds. This recording captures the isolated regular-pane fixture on the existing simulator. CPU sampling was disabled; no performance claims use the capture helper's old measurement data.

The focused clip is `/tmp/newsblur-scroll-evidence/title-selection-scan-132.mp4`. It is decoded from the original recording and encoded at 60 fps for playback; its frame rate is not a measurement of rendering performance.

The full suite in run 133 caught two failures: the replacement fixture did not exercise the real full-text response path, and the existing notification-return regression lost its row after an estimated-height table detached. The replacement test now calls `finishFetchText:storyId:` with the matching story ID, updating the same page, active-story, and text-mode state as a real response. Runs 134 and 136 both passed all 72 article-loading tests, including that held-parser replacement and every new selection test. Their remaining failure was the notification-return case.

The notification trace in run 136 identified the lost anchor: a visible target at row y=982 and content offset 534 belonged to a table still reporting estimated content height 666. Detachment clamped the offset to 58 before the next page response captured its anchor, so the response preserved the first row instead of the selected notification. Run 135 in isolation passed, but its test diagnostics themselves queried row/cell geometry and affected estimated-height materialization. It is not used as proof that the regression was resolved.

Run 137 passes the complete **381-test iOS suite**, zero failures or skips, in 170.280 seconds. The notification selection now saves its measured row and offset before presentation, reuses them for detached-table updates, and clears them when the user drags, taps the status bar, resets the feed, or selects another story. Restoration verifies a visible, measured target and also accepts a genuine final content-boundary clamp. All temporary notification diagnostics are removed. The existing regression passes both attached and detached cases, retains the original offset, and issues no unintended page-four request.

Run 138 strengthens the same regression by selecting another story while restoration is still pending. It reproduces two failures: the remembered anchor clears, but the pending anchor survives. The selection branch now also clears the pending anchor. This is the only production change after run 137.

Run 139 passes that complete targeted regression in 3.534 seconds, including both attached/detached layouts, final-boundary clamping, status-bar/drag cancellation, and selecting a different story during pending restoration.

Run 140 passes the complete **384-test Mac Catalyst suite**, zero failures or skips, in 150.679 seconds. All 73 article-loading cases pass, including real painted scans and held full-text replacement. It also validates the final notification cancellation fix, menu/preferences, feed counts, adaptive headers, authentication reset, and existing cell rendering/performance regressions. The Mac Computer Use connection still fails at native-pipe startup; these are Catalyst runtime tests, not a manual signed-in desktop interaction check.

Run 141 passes all **seven focused tests on the physical ClayPad Air**, zero failures or skips, in 10.155 seconds. It covers six animation/loading methods and the notification-return case. Adjacent selections produce 18 distinct presented positions and complete 287–292 ms after readiness; distant direct selections produce 22–23 positions and complete 358–370 ms after readiness. No production source changed after the full Mac suite.

Reviewing the Mac and physical-iPad attachments found that nested `drawHierarchy` captures of UIKit's frozen-page snapshot show the underlying source article. Run 142 adds a wait for two actual display callbacks and validates the cover's window, size, visibility, opacity, and snapshot child. The test passes in 1.302 seconds, but its hierarchy capture still shows the source. Native compositor capture is needed to distinguish an omitted snapshot surface from a visible regression; passing DOM assertions alone do not answer that question.

Run 143 attempts `XCUIScreen.main.screenshot()` from the hosted Catalyst test. XCTest rejects it with `Not authorized for performing UI testing actions`; this is a capture-infrastructure failure, not an article assertion failure. The unsupported capture call is removed, retaining run 142's passing geometry/display checks. The attachment is explicitly labeled as a hierarchy capture. A missing compositor-backed snapshot in nested capture is the leading explanation, but the held-cover pixels on Mac/physical iPad remain a manual verification limitation. The ordinary scan's real rendered pages and direction/duration checks pass on both platforms and the physical iPad.

## Installed builds

The normal signed Release builds succeed in `/tmp/newsblur-device-selection-release-144.log` and `/tmp/newsblur-mac-selection-release-144.log`. Both pass strict recursive signature verification and contain no performance XCTest bundle. The Mac build omits the test host's incoming-network entitlement. No production source changed after the passing Mac suite and physical-iPad run.

- ClayPad Air: installation and normal launch succeed with performance instrumentation disabled. `claypad-selection-install-144.json` and `claypad-selection-launch-144.json` identify the installed Alpha bundle and running PID 1993.
- ClayPhone SE 3: installation and normal launch succeed after the device is unlocked. `clayphone-selection-install-144.json` and `clayphone-selection-launch-144.json` identify the installed Alpha bundle and running PID 46083.
- Mac: the normal build is installed at `/Users/sclay/Applications/NB Alpha.app`. Its executable SHA-256 matches the built bundle: `5bbb9891b9f90e2f1c736f822810962dd7e82056018fc6eb5110e1123acff5a6`. The previous user-folder copy is preserved at `/tmp/newsblur-mac-before-selection-144.app`. The older root-owned `/Applications` copy is unchanged; launch the user-folder copy explicitly. Manual Mac launch remains unverified because Computer Use cannot start its native connection.
- Existing simulator: normal launch succeeds as PID 70521 with instrumentation disabled. `selection-normal-handoff-144.png` confirms the preserved `samuel` session and populated feed list.

The final whitespace and JavaScript syntax checks pass. All changes remain uncommitted and unstaged in the original performance worktree; HEAD remains `8e63e63dd`.
