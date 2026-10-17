# Divider drag regression

Reported by Sam while checking Android 16.0.1 build 293 on the Samsung SM-X200 tablet. The resize target was hard to grab, continuous movement lagged, and the boundary jumped after release. Build 293 was uploaded to a Play draft but must not be submitted.

Before source: `8eb2afd5698a729f454864e5fbd3efcd5fb3cc58`.
Device: `R8YW810E3FF`, Android 14, 1920 by 1200 pixels, density 240. The device's Window Extensions vendor API level is 3, so extension-7 embedding animation controls are unavailable.

`newsblur-reader-drag-before.mp4` records a four-second story divider drag from x=850 to x=1100, y=450. Android pointer location was enabled for this capture and restored afterward.

The feed screenshot sequence starts at boundary x=827, presses x=823, moves to x=750 and then x=650. The immediate held frame still shows the boundary near x=753 with clipped adjacent content. The released frame settles near x=653. Separate MOVE events followed by a two-second hold do settle before UP, distinguishing continuous input handling from a completely missing resize callback.

The code removes and reschedules its pending animation callback on every MOVE, which can postpone live updates under continuing input. ACTION_UP also ignores its final coordinate. Regression tests and fixed-build runtime evidence are required before release.

The first fix keeps one pending resize callback while updating its target, uses the final UP position, and expands the invisible target from12dp to32dp inside the owning list. Toolbar and footer buttons remain available. Both baseline tests failed before the change; the focused31-test set passed afterward. Device validation of this first fix is still pending, especially the API3 embedding animation behavior.
