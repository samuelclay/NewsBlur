# Story header width

The user reports the Related/Discover action collapsing to a few pixels in ClayPad Air's story-list header, beside Unread · Newest, Search, and the compound mark-read action. The requested compact behavior is to shorten the visible filter label while retaining the Discover icon. The supplied screenshot is `/Users/sclay/Downloads/Read Home.png`.

## Reproduction

Work uses the existing `ios-scroll-performance` worktree and booted iPhone 17e simulator (`3AD72704-02E5-4B1D-AA90-02413F046991`), with NB Alpha. Test-first commit `ff4a7a682` adds `StoryTitlesHeaderBarLayoutTests.swift` to the Alpha regression target. The tests construct the real header and run its Auto Layout and bounds-change callbacks at 320 and 600 points wide, including repeated transitions between those widths.

The clean red result is `header-width-red-49.xcresult`: three cases executed, with 13 expected assertion failures in the narrow and resize cases; the wide control passes. At 320 points the Discover button has **zero width** and is not hittable, while the full Unread · Newest label remains visible. The inspected `header-width-red-render-49/6A727AC8-0F77-47F7-97FE-B0B176DE560C.png` renders that missing action. Local evidence paths in this report are under `/tmp/newsblur-scroll-evidence` unless otherwise specified.

## Cause

`StoryTitlesHeaderBar.swift` protects the full filter label, Search, and the mark-read group from compression, while Discover has low compression resistance. Existing adaptive logic removes text from Discover and Search but cannot shorten the filter. The width calculation can still exceed the available column, leaving Discover to absorb the deficit. Its estimates also differ from the mark-read group's constraints, and some layout decisions depend on the preceding compact state.

## Responsive layout

Fix commit `42faa21a2` stores the current filter and sort order separately, measures real configured buttons, and first budgets for visible actions with icon-only Related and Search controls. When the full filter/order title does not fit, its visual label becomes Unread or All; the complete description remains available to accessibility and the existing options menu. Wider layouts restore the full title.

Width selection uses the actual compound mark-read width and visible stack spacing. At narrower divider positions it gives up excess mark-read padding while retaining separate menu and main-action regions. The conflicting fixed width on the main mark-read button is removed. Optional Related text, related-site favicons, Search text, and Daily Briefing settings adapt from the current width rather than a previous layout state. Unchanged layouts retain their favicon views and avoid scheduling more layout work.

## Validation

The final result, `header-width-final-51.xcresult`, passes all 14 focused tests: eight header layout cases and six existing menu preference cases, with zero failures in 0.820 seconds. Build and execution logs are `/tmp/newsblur-header-width-final-build-51.log` and `/tmp/newsblur-header-width-final-51.log`. This follow-up runs the focused suites, not the full regression target.

Coverage includes widths from 300 through 600 points, both filter and sort values, repeated resizing, hidden actions, Daily Briefing, related-site favicons, active search colors, accessibility descriptions, and independent mark-read/menu actions. At 320 points the filter becomes Unread and Discover is at least 40 points wide and hittable; at 390 and 600 points the full filter/order label remains. Twenty unchanged layout passes retain the same favicon views and frames without additional header layout callbacks.

An intermediate run (`header-width-after-50.xcresult`) passed the feature/layout checks but exposed a test fixture mistake: UIKit initially supplies distinct menu instances to the two mark-read buttons. The final test records each button's own initial menu identity and verifies that each survives resizing, while checking their matching menu contents. No production change was needed for that correction. The inspected after render, `header-width-after-render-50/BEAC22D9-9140-4A78-BD3C-7F5BFAE7020A.png`, uses the same final production implementation and shows the complete Related icon beside the shortened Unread label.

The ordinary signed-in simulator app also opens Related sites from the icon (`header-width-related-menu-51.png`) and exposes Newest/Oldest and All stories/Unread only in the options menu (`header-width-options-menu-51.png`). Screenshots were inspected. No preferences were changed and mark all read was not invoked. The narrow iPad column is exercised by the real UIKit header fixture; these live menu captures use the existing 390-point iPhone simulator.

## Physical device update

The Release device build succeeds (`/tmp/newsblur-header-width-device-build-51.log`), and `codesign --verify --deep --strict` passes. The NB Alpha executable SHA-256 is `61702cac70ba1a8006204d46da0a771465d0b8fb6b17d0dc612af2d787875eb9`.

The same `com.newsblur.NB-Alpha` build was installed wirelessly and successfully launched in the foreground on both devices:

| Device | CoreDevice identifier | Launched process |
| --- | --- | --- |
| ClayPad Air | `C78768E8-4867-5C24-8298-FF27334049EE` | `1680` |
| ClayPhone SE | `E62ABF72-70BD-5647-BC74-689A513A4EBE` | `43334` |

Installation and launch evidence is in `/tmp/newsblur-claypad-header-width-{install,launch}-51.{json,log}` and `/tmp/newsblur-clayphone-header-width-{install,launch}-51.{json,log}`. Both launch results report success with `activatedWhenStarted: true`. Performance probes are disabled. Physical installation and foreground launch are verified; direct interaction with the narrow header on the physical iPad is not automated here.
