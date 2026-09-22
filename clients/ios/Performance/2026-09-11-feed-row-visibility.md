# Feed rows after scrolling to top

The user reports three blank feed rows below Absolute Newsletters on ClayPad Air after reading stories and tapping the iPad status bar time to scroll to the top. The supplied screenshot is `/Users/sclay/Downloads/Read Any Broken Feeds, Although Some of These Work Fine.png`.

Investigation uses the existing `ios-scroll-performance` worktree and booted iPhone 17e simulator, `3AD72704-02E5-4B1D-AA90-02413F046991`, with NB Alpha. The ordinary account screenshot `feed-blank-start-45.png` and the initial fast-scroll/status-bar control `feed-blank-jump-before-45.png` show intact rows. That control does not change unread counts and does not reproduce the reported blank area.

## Reproduction

Test-first commit `aaea13960` adds two regressions to `HiddenFeedRowPerformanceTests.swift`. The real-table test renders three unread newsletter rows, moves them offscreen, changes their counts to zero, updates visible badges, and returns to the top through UIKit. Each row retains its original positive-height frame, but the data source supplies `BlankCellIdentifier` instead of a feed cell. The direct row regression also shows that favicon prefetch skips this retained row.

The clean before result is `feed-blank-red-46.xcresult`, with 10 tests executed and nine expected assertion failures in the two new cases. The previous eight controls pass. The first attempt, `feed-blank-red-45.xcresult`, ran only the eight previously installed cases despite a rebuilt test binary. Explicitly installing the rebuilt NB Alpha with `run_ios.py`, then running `test-without-building`, executes all 10; that earlier result is not the regression checkpoint.

The exported `feed-blank-red-render-46` attachments visibly show Newsletter 1, 2, and 3 initially drawn, then three empty rows after returning to the top. These are rendered UIKit fixtures at a 320-point sidebar width, with isolated counts and no account mutations. The regression exercises cell reuse and the scroll-to-top destination, rather than synthesizing a physical iPad status-bar event. Local evidence paths in this report are under `/tmp/newsblur-scroll-evidence` unless otherwise specified.

## Cause

`FeedsObjCViewController.m` caches row heights for stable scrolling. Count-only refreshes keep that table geometry intact. However, cell creation separately evaluates current unread visibility and can substitute an empty cell when the unread count reaches zero. Favicon preparation repeats the same inconsistent decision. A scroll-to-top jump exposes the mismatch when UIKit asks for those offscreen rows again.

## Fix and related preference behavior

Cell creation and favicon preparation now use the same resolved row-height visibility as the table. The redundant live unread checks are removed. Count-only refreshes continue to retain existing geometry, with no new table reload or change to cell artwork. Explicit feed reloads, collapse changes, and search/filter changes still recompute visibility.

The intermediate `feed-blank-candidate-47.xcresult` runs 23 cases. The original blank-row regressions and all eight unread-count refresh tests pass. Its only two failed assertions expose a related deselection bug: removing a feed's retained-visible marker still leaves its cached 34-point height intact. The final change clears the existing markers before that deliberate row reload and invalidates only the affected row-height entries. Additional controls exercise two retained feeds with the show-after-reading preference both enabled and disabled.

The inspected `feed-blank-candidate-render-47/40AA8AED-FFAE-4A63-964A-D9361F1AC7ED.png` shows all three newsletter titles still drawn after returning to the top; their unread badges are absent, while the following unread rows retain their badges.

## Final verification

Fix commit `f84324720` passes the complete Alpha suite: **313 tests, zero failures, in 99.347 seconds**, with `xcodebuild` exiting zero. Evidence is `feed-blank-full-after-48.xcresult` and `/tmp/newsblur-feed-blank-full-after-48.log`. The 16 hidden-feed cases and eight unread-count cases pass, including both deselection preference settings. The final rendered attachment `feed-blank-final-render-48/7D4F05F2-1D36-4B90-BA09-3CCC48816FAC.png` again shows the three read feed titles intact after returning to the top.

The final ordinary app remains signed in as samuel. A 17.355-second recording, `feed-blank-status-bar-after-48/scroll.mp4`, captures 12 forward/reverse feed-list gestures with seed 911, followed by tapping the status bar time. Its inspected `end.png` shows complete feed rows at the top. This is a functional status-bar control with performance probes and CPU sampling disabled; the isolated count-depletion regression supplies the before/after reproduction. No live story read mutation or mark-all-as-read action was used in this follow-up, and the tests restore the preference values they temporarily change.

## Physical devices

The signed Release build passes signature verification (`/tmp/newsblur-feed-blank-device-build-48.log`). Executable SHA-256: `1d91a9fe8f0e082260cd59113d0556f7f0d86975cd000f15109effc3afd9c4d7`.

The updated NB Alpha installs over Wi-Fi and successfully launches in the foreground on ClayPad Air (PID 1636) and ClayPhone SE 3 (PID 42652), with performance probes disabled. Both executable paths match their new installations. Evidence is `/tmp/newsblur-claypad-feed-blank-{install,launch}-48.json` and `/tmp/newsblur-clayphone-feed-blank-{install,launch}-48.json`. Installation and launch are verified on the physical devices; direct iPad sidebar scrolling remains a user verification step.
