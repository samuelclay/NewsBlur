# Reader toolbar scrolling

Android now uses a CoordinatorLayout and native AppBarLayout nested scrolling for the reader. The header moves out with forward scrolling. Once fully hidden, the first 30dp of a reverse drag do not reveal it; subsequent movement reveals the header one-for-one. The bar snaps to its nearest endpoint when the drag ends. At the top of the article, it can return immediately. Bottom controls fade with the header's visible fraction.

The reference is `clients/ios/Classes/StoryToolbarScrollHandler.swift`. Its directional accumulation and proportional offset are retained, with the requested 30dp reverse threshold. The status-bar area has a fixed background from the existing theme palette and clips the moving header underneath it. Native offsets avoid resizing the WebView on each scroll frame.

The full-height left-edge view remains available while controls are hidden. On Android 14+, actual system-gesture insets determine whether system predictive back owns the edge. Three-button navigation uses the app's interactive back gesture. Story-selection callbacks reveal controls on the main thread.

## Verification

- Debug and Alpha builds pass.
- 20 focused unit tests pass: threshold accumulation and direction changes, gesture ownership, reader tap gestures, edge-to-edge margins, and prepared entrance/back cancellation.
- The gesture-ownership regression first failed for Android 15 with three-button navigation; the corrected policy passes.
- Existing emulator and Samuel session were retained. No instrumentation install or mark-all-read operation was used.
- Theme captures show the header initially visible, hidden, below the reverse threshold, partially revealed while the finger remains down, fully revealed, and interactive back in progress/completed. The status-bar background remains themed in every state.

Manual replay: open a long story, swipe upward to hide the controls, reverse a small amount (below 30dp), then continue reversing past 30dp while holding the gesture. The toolbar should progressively emerge. Hide it again, drag from the left edge and cancel, then complete an edge swipe to return to story titles.

### Installed UI results

Verified on the existing API 35 Pixel 5 emulator, signed in as Samuel:

| Theme | Hide / reverse threshold / partial reveal | Edge back cancel / complete |
| --- | --- | --- |
| Light | Pass | Pass |
| Dark | Pass | Pass |
| Black | Pass | Pass |
| Sepia | Pass | Pass |

Landscape was also checked for hidden, below-threshold, partial, and fully revealed states, followed by returning to story titles with the controls hidden. Landscape captures were inspected directly; UIAutomator could not reliably obtain an idle hierarchy for the article. The same full-bleed image remains flush with the article viewport during toolbar movement.

`reader-toolbar.mp4` records the installed build during the light and dark checks. The PNGs include held intermediate states so the threshold and proportional reveal can be reviewed independently of the recording timing.

System gesture navigation was separately enabled and verified on the final build: a hidden-toolbar edge swipe could be canceled without leaving the reader, and a completed swipe returned to story titles. The original three-button navigation mode was restored afterward. Navigation-mode changes recreate the activity, so verification waits for the reader to settle before sending scroll input.
