# Reader offset and emulator performance investigation

Tested the existing Pixel 5 API 35 emulator, signed in as Samuel, on app code at
`9797c29ea` (branch HEAD `bd4a6a3d9`). No application code changed in this investigation.

## Environment contributes substantially to the lag

The initial host sample showed 0% CPU idle, a load average of 69 on 10 cores,
and approximately 13 GB of compressed memory. The emulator was running with
four virtual CPUs and `-gpu software`, a workaround for earlier emulator hangs.

Repeated six alternating 650 ms vertical drags on the same Engadget Ethernet
story, resetting `dumpsys gfxinfo com.newsblur` before each run. There was a
one-second pause after each drag. No screen recording ran during these samples.

| Metric | Software rendering | Host GPU rendering |
| --- | ---: | ---: |
| Rendered frames | 91 | 247 |
| Frames missing their deadline | 100% | 53.44% |
| Median frame time | 200 ms | 53 ms |
| 90th percentile | 300 ms | 109 ms |
| 95th percentile | 350 ms | 129 ms |
| 99th percentile | 450 ms | 150 ms |

These are environment comparisons, not an app optimization benchmark. Host
load changed between runs: the later sample had 15–19% CPU idle and a load
average near 25. Gesture delivery, rendered frame count, and resulting scroll
distance also differ under severe scheduling delays. The measurements cannot
separate the GPU-mode improvement from reduced host contention, nor establish
physical-device performance. Neither run meets the 60 Hz frame budget.

Restarted the same AVD without wiping data, using:

```sh
~/Library/Android/sdk/emulator/emulator -avd Pixel_5_API_35 \
  -gpu host -cores 4 -feature -Vulkan -no-snapshot -no-audio
```

The emulator reported the Apple M1 Max OpenGL translator. It remains open with
hardware rendering and Samuel's login. No unrelated host processes were stopped.
The Samsung device was not attached during this investigation.

## Reported next-story offset remains unconfirmed

Captured the screen before reproducing. Each following case kept the toolbar
hidden and showed the entire incoming title. Native UI bounds showed a 28 px
gap between the incoming scroll viewport and title, consistent with the existing
10 dp title margin at the emulator's density, without a toolbar-height scroll offset.

| Case | Scroll viewport top | Title top | Screenshot |
| --- | ---: | ---: | --- |
| Bloglets folder, Next unread | 205 | 233 | [Folder](folder-hidden-next.png) |
| Engadget, adjacent next page | 158 | 186 | [Feed](feed-hidden-next.png) |
| Fast fling followed immediately by adjacent next | 158 | 186 | [Fling](fling-hidden-next.png) |
| Landscape, adjacent next page | 88 | 116 | [Landscape](landscape-hidden-next.png) |

Keyboard N exercises Next unread; K exercises adjacent next navigation. These
checks do not prove that a physical tap during an animation, every title-selection
route, or restoration of a previously visited page is correct.

A read-only audit found per-story scroll restoration keyed by story hash, and
no transfer of the outgoing fragment's scroll offset to a preloaded neighbor.
Remaining possibilities include saved-position restoration on a revisit, native
focus/viewport adjustment, or a transient snapshot shift during toolbar movement.
None has enough evidence for a corrective code change yet. A blanket scroll-to-top
would discard legitimate reading positions and was not added.

The folder reproduction recording is retained locally at
`/tmp/nb-toolbar-offset-before.mp4`. Raw graphics samples are at
`/tmp/nb-software-controlled-gfxinfo.txt` and
`/tmp/nb-hardware-controlled-gfxinfo.txt`.
