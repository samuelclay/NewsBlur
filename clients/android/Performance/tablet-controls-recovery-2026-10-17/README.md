# Recovering the Android tablet controls

The Samsung tablet was running NewsBlur and NB Alpha 15.1 (291). Its feed and story-title lists lacked their independent fullscreen controls and resize handles. The reader's own fullscreen button remained available.

The missing work was found on ClayBook M4's local `main`, in two commits that had not reached origin:

- `e287b420d6acaf2c1ca8b76eaefe30b90c5681f6`: independent feed and story-title fullscreen choices.
- `7adec3eed7e9119ddc3fcbaac4539b68fa382863`: persistent tablet panes and saved divider widths.

Both were committed October 12 on top of `95cded69f`. The recovery merge retains both original commits and integrates the later internationalization and fixed Next-button changes. Feed panes and drag directions now mirror for Arabic and Hebrew, including language changes within the running process.

## Before evidence

- `before-feeds.png` and `before-titles.png`: the tablet's original Alpha screens, captured before source changes.
- `baseline-failing-tests.xml`: both new regressions fail on the original checkout. The feed toolbar lacks its fullscreen button, and list activities would recreate when resized.

The recovered `StorySplitViewTest` covers resize configuration handling, so the equivalent temporary baseline test was consolidated into that existing suite. `Test_TabletControlsRecovery` retains the independent feed-toolbar accessibility regression.

## Validation boundary

The focused recovery suite passed 35 tests with no failures or errors. It covers independent fullscreen modes, pane windows, theme changes, divider cancellation, sizing, resize animation policy, and RTL direction. Device validation, the full suite, and the version 16.0.1 release are recorded separately by the release workflow.
