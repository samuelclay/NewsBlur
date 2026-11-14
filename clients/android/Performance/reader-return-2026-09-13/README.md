# Returning from the Android reader

Tested on September 13, 2026, using Samuel's existing account in the Pixel 5 API 35 emulator. No account reset or mark-all-read action was used.

## Changes

- Keep read timers attached to the selected story. Cancel them synchronously on selection changes, committed Back, and pause. A resumed reader starts a fresh dwell; time on the home screen does not count.
- Start dwell after the prepared reader entrance is visible. Preserve manual marking and the rotation restore guard.
- Correct the 45-second and 60-second options, which previously waited 40 and 50 seconds.
- Return to the actual last viewed story, including when an older manually marked story is still cached.
- Bring an offscreen returned story into view and hold its themed highlight during the reader exit. Start the one-second fade on a visible list frame after the exit completes. Keep the target through partial data batches and preserve the fade through read-state rebinding.

## Regression tests

Tests were added before implementation. [Initial return/delay failures](regression-before.log) reproduce three failures in 16 tests. [Initial reader dwell failures](dwell-before.log) reproduce seven failures in 11 tests.

The final combined run passed **416 tests, zero failures, errors, or skips**, and built both Debug and Alpha APKs. Both APKs were installed with their existing app data preserved.

```sh
env JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
  ./gradlew :app:assembleDebug :app:assembleAlpha :app:testDebugUnitTest
```

## Live return checks

| Theme | Marking preference | Result | Recording |
| --- | --- | --- | --- |
| Light | Immediately | Advanced 20 stories using the reader's K/Next command. Every destination had `read=1`; the final title returned at `[64,454][500,529]`. | [Twenty-story return](light-return.mp4) |
| Dark | Immediately | Advanced two stories; both had `read=1`. Returned to the final title with its highlight. | [Dark return](dark-return.mp4) |
| Black | Manually | Advanced two stories; both retained `read=0`. The final title still received the return highlight, which faded without marking it read. | [Manual marking return](black-return.mp4) |
| Sepia | Immediately | Advanced two stories; both had `read=1`. Returned to the final title with its highlight. | [Sepia return](sepia-return.mp4) |

The edge-back recordings hold the drag midway, then complete it. The highlight stays present while the reader covers the list, then fades after the list is exposed. The PNGs include intermediate transition frames and the settled list; `returned.png` can still show the end of the exit animation because it is captured shortly after releasing the gesture.

[Twenty-story database and visible-title checks](light-twenty-story-run.txt) record each destination. A separate live horizontal swipe also advanced to a different story and marked it read. Some automated swipes were dropped by the emulator, so the twenty-story run uses the reader's Next command rather than counting unconfirmed swipes.

## Live five-second dwell check

Before the fix, opening an unread story, leaving for HOME before five seconds, and waiting seven seconds incorrectly changed its database state to `read=1`: [before](dwell-runtime-before.txt).

After the fix, an unread story remained `read=0` after leaving for HOME and waiting seven seconds. Resuming through Recents marked it `read=1` after its prepared entrance and five-second dwell completed (10 seconds total on this slow emulator). Back returned to the same title: [after](dwell-runtime-after.txt), [resumed reader](dwell-after-resume.png). The exact dwell boundary is covered by virtual-time unit tests; this runtime check includes rendering and scheduling delays.

The emulator was left on the light theme with immediate read marking for normal testing. Manual and delayed marking remain available and were exercised above.

## Test environment limitations

The original emulator guest hung after seven advances, including ADB shell commands. Hardware rendering and a software-rendered window both needed recovery. The completed checks reused the same AVD with software rendering, no emulator window, four cores, and a 720 × 1560 override at 293 dpi. That keeps approximately the same logical viewport as 1080 × 2340 at 440 dpi while reducing rendered pixels. All three Android animation scales remained **1.0**.

These recordings establish navigation, read state, and highlight ordering. They are **not a frame-rate benchmark**: the host was heavily loaded and software rendering remained slow. The interrupted run is not counted as a pass.
