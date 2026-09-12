# Android scrolling audit — September 12, 2026

**Progress report:** the latest build passes 330 tests. Rapid folder toggles and prepared Next/Previous navigation pass in all four themes; backgrounding during far-page preparation and resuming also passes. Runtime replay of a newly fixed rapid-navigation race, Back during far-page preparation, corrected navigation timing, and a proper long-article scrolling comparison remain pending. The timing captures below precede the latest animation/navigation fixes; this report does not mark the audit complete.

The audit found and fixed unnecessary story-cell work, missing section/read-state animations, and overlapping canceled sync generations. The sync overlap was an application bug: cancellation left blocking network/HTML parsing alive while replacements started, and the paging loop checked the service's lifetime instead of its own canceled generation. Stress logs showed competing database/Spannable locks and repeated large garbage collections. Host/emulator scheduling is an additional limitation, not the sole explanation.

The recorded timings do **not** establish a reliable overall frame-rate improvement. Early UI-only measurements below precede the sync fix. Final captures are observations under a heavily loaded host; cache state, live account changes, and frame-presentation outliers are not controlled.

## Setup and reproduction

- Worktree: `android-scroll-performance`; initial source anchor `362ae7d35`, story binding `eefa8ea86`, sync serialization `82b3db2e0`, prepared reader entrance `26ea0719e`, coalesced refresh requests `a67de5799`, latest-feed query publication `0531487fe`, same-query snapshot completion `32a65b75f`, canceled reader entrance on Back `b95bb2944`, immutable page/session guard `660e8fd96`, immediate cached feed startup `193a9e17f`, serialized adapter publication `daefdc29c`, first-story anchor above the footer `1d9a4e0cd`, folder collapse scroll-clamp geometry `516ef2024`, related-story date spacing `535fe34fa`, article-body readiness before entrance `9ec4d6c0c`.
- Existing Pixel 5 API 35 ARM64 emulator, 1080 × 2340, density 440, four virtual CPUs. NewsBlur `com.newsblur`, debug version 14.5.8 (283).
- Logged in as `samuel`, using the existing large subscription/story collection. Mark read on scroll enabled. No mark-all-read, application-data reset, or connected instrumentation tests.
- The `baseline/`, `after/`, and `final/` captures use the host OpenGL backend with Vulkan disabled, Skia OpenGL in the guest. Sharing a renderer does not make these controlled benchmarks. Earlier `before/` captures include other rendering configurations and must not be mixed into this comparison.
- The later `baseline-speed/`, `final-coalesced/`, and `final-reviewed/` runs compile the installed package with `adb -s emulator-5554 shell cmd package compile -m speed -f com.newsblur`. This changes ART compilation state from earlier runs. Compare only captures that received the same treatment; reduced cold JIT work cannot be attributed to the source changes.
- Initial feed and story-title scenarios use three upward and three downward 450ms swipes, with one second between gestures. The later `baseline-speed/feed-long-timing/` and `baseline-speed/titles-timing/` scenarios use six 1200ms swipes because delayed dispatch sometimes turned shorter gestures into taps. Detail baseline: three Next taps, two Previous taps, then an upward and downward story scroll. Use each capture's recorded gestures for its comparison.
- Separate recordings retain visual evidence; `*-timing` runs disable screen recording to reduce recording overhead. Each directory contains the actual gesture coordinates/timestamps, screenshots, trace configuration, Perfetto trace, and `gfxinfo` output.

Use the existing attached device and open the relevant screen before running:

```sh
ruby clients/android/Performance/scroll_profile.rb emulator-5554 /tmp/newsblur-android-profile/repeat/feed-timing /tmp/newsblur-android-profile/baseline/feed-timing/gestures.json --no-video
/tmp/newsblur-trace-processor query -f clients/android/Performance/profile_slices.sql /tmp/newsblur-android-profile/repeat/feed-timing/trace.perfetto-trace
/tmp/newsblur-trace-processor query -f clients/android/Performance/detail_scheduler.sql /tmp/newsblur-android-profile/final-reviewed/detail-timing/trace.perfetto-trace
```

The query isolates NewsBlur's main thread. It excludes nested Choreographer resynchronization slices and measures scheduled CPU time by intersecting operation spans with scheduler slices. This excludes guest thread descheduling, but does not remove every source of host/emulator timing distortion. Cell spans exclude asynchronous thumbnail download/decode completion.

## Initial UI candidate measurements, before the sync fix

Times below are milliseconds from the no-video timing captures, expressed as **baseline → after**. These are individual recorded runs, not confidence intervals.

| Operation | Samples | Median wall time | Mean wall time | Mean scheduled CPU time |
| --- | ---: | ---: | ---: | ---: |
| Feed `obtainView` | 45 → 48 | 3.584 → 4.939 | 11.141 → 12.927 | 10.157 → 10.068 |
| Feed `setupListItem` | 45 → 65 | 0.776 → 0.658 | 1.869 → 2.985 | 1.835 → 1.469 |
| Story `onBindViewHolder` | 11 → 4 | 30.174 → 16.260 | 37.968 → 16.480 | 22.794 → 9.954 |
| Story `onCreateViewHolder` | 0 → 3 | unavailable → 140.897 | unavailable → 110.810 | unavailable → 69.251 |
| Feed Choreographer frame | 98 → 92 | 29.352 → 27.921 | 56.154 → 48.939 | 13.334 → 11.122 |
| Story-list Choreographer frame | 87 → 56 | 18.890 → 37.036 | 69.641 → 67.613 | 16.956 → 16.714 |

`gfxinfo` provides an additional frame-level check and does not show a consistent gain:

| View | Rendered frames | Janky frames | Frame duration p50 | Frame duration p95 |
| --- | ---: | ---: | ---: | ---: |
| Feed list | 79 → 85 | 75.95% → 76.47% | 81 → 73ms | 400 → 500ms |
| Story titles | 83 → 48 | 83.13% → 93.75% | 129 → 200ms | 750 → 1450ms |

These frame results include render-thread and presentation delays; they are not interchangeable with main-thread Choreographer durations. Perfetto attributes many late feed frames to both SurfaceFlinger and app deadline misses. Several virtual-GPU histograms saturate their final 4950ms bucket. The differing holder creation/cache states, live account mutations, small sample counts, and large scheduling/rendering outliers preclude an honest FPS or percentage-speedup claim.

The detail baseline contains 325 main-thread Choreographer frames, with median 4.880ms, mean 18.947ms, and mean scheduled CPU 1.097ms. `gfxinfo` records 163 rendered frames, 49.69% janky, p50 42ms and p95 150ms. This is **baseline only**; WebView renderer/GPU work is not fully represented by the app main-thread number.

## Intermediate sync candidate observation

The completed `final/feed-timing/` run includes serialized sync but predates the followup request-coalescing and latest-story-load fixes. Its directory name does not mean it represents the final source revision. During this run, the host load was approximately 20; an earlier launch also stalled during native class loading before app initialization.

| Operation | Samples | Median wall time | Mean wall time | Mean scheduled CPU time |
| --- | ---: | ---: | ---: | ---: |
| Feed `obtainView` | 76 | 1.212ms | 9.360ms | 7.629ms |
| Feed `setupListItem` | 111 | 0.586ms | 8.325ms | 6.841ms |
| Feed Choreographer frame | 71 | 66.461ms | 124.041ms | 35.801ms |

`gfxinfo` recorded 85 frames, 94.12% janky, p50 150ms and p95 950ms. The lower median cell acquisition cost does not establish smoother presentation: full-frame timings were worse and setup/layout outliers remained large. This observation is retained to avoid selecting only favorable runs.

## Later baseline with matching ART compilation

`baseline-speed/feed-long-timing/` stayed in `Main` throughout six 1200ms swipes, starting and ending at the top of the feed list. `baseline-speed/titles-timing/` stayed in the Engadget story list with All selected before and after the same gesture pattern. These provide baselines for the final matching scenarios. Host/emulator presentation recovered substantially even though these use the baseline app, demonstrating why earlier timing differences cannot be attributed solely to source changes.

| Baseline operation | Samples | Median wall time | Mean wall time | Mean scheduled CPU time |
| --- | ---: | ---: | ---: | ---: |
| Feed obtainView | 41 | 1.446ms | 4.506ms | 3.937ms |
| Feed setupListItem | 41 | 0.315ms | 0.564ms | 0.557ms |
| Feed-list Choreographer frame | 448 | 7.683ms | 13.420ms | 2.403ms |
| Story bind | 14 | 1.663ms | 2.035ms | 1.808ms |
| Story create | 5 | 4.124ms | 5.520ms | 5.158ms |
| RecyclerView scroll | 372 | 0.170ms | 0.484ms | 0.388ms |
| Story-list Choreographer frame | 547 | 4.516ms | 7.416ms | 1.674ms |

Feed-list `gfxinfo` recorded 403 frames, 32.01% janky, p50 27ms and p95 93ms; median GPU time was 4ms. Story-list `gfxinfo` recorded 477 frames, 14.26% janky, p50 19ms and p95 57ms; median GPU time was 3ms. Matching final-source feed/title runs and a qualified detail observation are below.

`baseline-speed/detail-timing/` also stayed in `FeedReading`. It recorded 441 main-thread Choreographer slices with median 0.157ms, mean 6.642ms and mean scheduled CPU 0.972ms. The 38 rendered frames were 76.32% janky, with p50 113ms and p95 550ms. The large difference between main-thread slices and rendered frames illustrates how little a main-thread-only number says about WebView presentation.

## Final matching feed-list observation

`baseline-speed/feed-long-timing/` and `final-coalesced/feed-timing/` both use ART speed compilation, Dark theme, and six 1200ms swipes. Both stay in `Main` and start/end at the top of the feed list. Times are milliseconds, **baseline → final**.

| Operation | Samples | Median wall time | Mean wall time | Mean scheduled CPU time |
| --- | ---: | ---: | ---: | ---: |
| Feed obtainView | 41 → 58 | 1.446 → 0.642 | 4.506 → 3.504 | 3.937 → 2.493 |
| Feed setupListItem | 41 → 58 | 0.315 → 0.302 | 0.564 → 0.552 | 0.557 → 0.495 |
| Choreographer frame | 448 → 628 | 7.683 → 4.801 | 13.420 → 9.344 | 2.403 → 1.654 |

`gfxinfo` recorded **403 → 581 frames**, **32.01% → 15.49% janky**, **27 → 20ms p50**, and **93 → 65ms p95**. This pair shows lower observed cell and frame times with the final build. It is still one live-account run per revision on a shared emulator; different acquisition counts and host scheduling prevent treating the difference as a stable percentage improvement or an FPS guarantee.

## Final matching story-title observation

`baseline-speed/titles-timing/` and `final-reviewed/titles-timing/` both stay in the Engadget list, with All selected, Dark theme, font scale 1.0, ART speed compilation, and six 1200ms swipes. They begin at the top and finish near the top. Two newly arrived live stories precede the older baseline content, so row/cache contents are similar rather than identical. Times are milliseconds, **baseline → final**.

| Operation | Samples | Median wall time | Mean wall time | Mean scheduled CPU time |
| --- | ---: | ---: | ---: | ---: |
| Story bind | 14 → 16 | 1.663 → 1.154 | 2.035 → 1.911 | 1.808 → 1.536 |
| Story create | 5 → 5 | 4.124 → 3.767 | 5.520 → 5.867 | 5.158 → 4.645 |
| RecyclerView scroll | 372 → 471 | 0.170 → 0.136 | 0.484 → 0.331 | 0.388 → 0.307 |
| Choreographer frame | 547 → 618 | 4.516 → 2.815 | 7.416 → 5.086 | 1.674 → 1.348 |

`gfxinfo` recorded **477 → 577 frames**, **14.26% → 7.11% janky**, **19 → 17ms p50**, and **57 → 36ms p95**. Observed binding and frame timings improved in this pair; mean holder creation time rose slightly despite lower median/CPU time. Five creations per run and the live-content/host differences are insufficient for a stable creation-cost or overall percentage-speedup claim.

## Story-detail observation with inactive Previous control

`baseline-speed/detail-timing/` and `final-reviewed/detail-timing/` both stay in `FeedReading`, starting on the Anthropic article and ending on the Windows battery article. Both use ART speed compilation. The requested sequence was three Next taps, two Previous taps, and two scrolls, but per-step replay later proved that Previous was disabled: the two Previous attempts did nothing. This capture therefore measures **three Next actions, two ignored Previous attempts, and two scrolls**, not successful bidirectional navigation. The baseline's matching final article does not establish that its Previous attempts worked either. Times below are milliseconds, **baseline → reviewed candidate**, pending a corrected replay and measurement.

These Engadget pages are short articles. Their navigation and two scroll attempts do not establish scrolling performance through a long article body. A matching long-body baseline/after scenario remains pending separately from corrected navigation timing.

| Operation | Samples | Median wall time | Mean wall time | Mean scheduled CPU time |
| --- | ---: | ---: | ---: | ---: |
| Choreographer frame | 441 → 203 | 0.157 → 0.895 | 6.642 → 14.635 | 0.972 → 1.316 |

`gfxinfo` recorded **38 → 85 frames**, **76.32% → 62.35% janky**, **113 → 61ms p50**, and **550 → 150ms p95**. Presentation timings were lower in these recordings, but main-thread median/mean and per-slice CPU time were higher, and the reader still missed many frame deadlines on this emulator. The inactive Previous control makes this an incomplete navigation scenario. Different numbers of Choreographer slices and rendered frames also prevent interpreting the per-slice mean as an overall frame-rate change.

Total-time analysis explains the higher per-callback mean: there are fewer callbacks with almost the same total wall time, and less scheduled main-thread work.

| Main-thread metric | Baseline | Reviewed candidate |
| --- | ---: | ---: |
| Callback wall time | 2929.191ms | 2970.943ms |
| Scheduled running time within callbacks | 428.678ms | 267.137ms |
| Runnable, awaiting guest CPU | 234.273ms | 187.305ms |
| Sleeping within callbacks | 2266.240ms | 2516.501ms |
| Scheduled running time across the whole capture | 1161.019ms | 660.916ms |

The reviewed callbacks spend 84.7% of their time sleeping, 9% running, and 6.3% runnable. `postAndWait` accounts for 2256.650ms as the main thread waits for the renderer. The longest callback takes 138.621ms wall time but only 1.534ms scheduled running time. RenderThread's 66 `WebViewFunctor::drawGl` calls total 2410.533ms wall time, versus 24 calls totaling 2267.434ms in the baseline. Final `glGetError encode` slices total 1443.155ms wall time and 1370.622ms guest-scheduled running time across 9092 calls. These nested/concurrent totals must not be added together.

This identifies work and waits in the WebView-to-emulated-GL path. The trace records the **guest Android scheduler**, not host macOS scheduling or sampled Java/native stacks. It cannot establish whether Mac-side stalls or encoder work explain each delay; host scheduling/GPU profiling would be needed for that distinction. Runnable guest CPU contention is a smaller component than graphics handoff waiting.

The 32.924ms CPU outlier at trace +1.940s is now accounted for: its animation phase takes 31.096ms scheduled CPU and includes WebView client initialization and JIT code-cache lock contention. Page creation/inflation totals 150.875ms across 11 slices. Native measure/layout totals are small (29.612ms and 14.981ms respectively), with no evidence that repeated full-list layout drives these reader stalls. These residual preparation costs do not identify a safe additional source fix without sampled stacks; enlarging the resident WebView window would be an unmeasured memory tradeoff.

The reusable `detail_scheduler.sql` records thread-state and graphics-slice attribution without account content. Its graphics-wait query is confined to each callback's main thread. The detailed investigation is retained in `/tmp/newsblur-detail-trace-review.md`, with scheduler exports `/tmp/newsblur-detail-{baseline,final}-scheduler.csv`. These observations do not establish physical-device FPS or a stable speedup.

## Row hardware-layer experiment

The final APK was tested in an A/B/A sequence with row hardware layers enabled, disabled, then enabled again. Each run used a fresh launch, ART speed compilation, Dark theme, and six 1200ms swipes in the same story list. All three validity records keep `FeedItemsList` in the foreground; each sampled 16 binds and five holder creations.

| Run | Rendered frames | Janky frames | Frame p50 | Frame p95 | Median bind | Median create |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A: enabled | 577 | 7.11% | 17ms | 36ms | 1.154ms | 3.767ms |
| B: disabled | 590 | 3.90% | 9ms | 25ms | 1.301ms | 3.094ms |
| A: restored | 592 | 3.21% | 7ms | 24ms | 0.962ms | 3.865ms |

The result is **inconclusive**. Presentation improved across the sequence even when the original setting was restored; the improvement was not specific to disabling layers. Binding CPU time also fell across all three runs (1.536, 1.230, and 0.978ms mean), consistent with changing runtime conditions. The production default remains enabled, and the emulator's debug preference was restored to `true`.

Evidence under `final-reviewed/`: `titles-timing/`, `titles-no-layer-timing/`, and `titles-layer-repeat-timing/`. This experiment does not support a source change to layer policy.

## Confirmed changes and validation

- Story rows retain immutable presentation snapshots. Read changes produce a small DiffUtil payload, including matched/related stories; edited title/thumbnail content still causes a full bind.
- Read appearance fades over 220ms without reparsing titles, clearing thumbnails, or changing row geometry. Feed/story headings share colors and stable weight; metadata stays non-bold. Read text uses one color in each supported theme.
- Ordinary read/sync diffs no longer save and restore the layout manager. Explicit navigation/configuration restoration remains supported.
- Parsed titles are cached by the actual HTML under a bounded character budget, retaining spans. Full binds preserve unchanged in-flight/loaded thumbnails.
- Folder/special-section expansion and collapse now animate and keep headings anchored. The initial and revised recordings are retained for visual review.
- Primary sync generations share a process-wide coroutine mutex; each subservice also serializes duplicate work. Canceled blocking operations and their children must finish before replacements run. Paging checks the current generation, canceled metadata remains pending, and cancellation does not discard reading actions. The latest foreground request survives superseded queued work and stopped scheduler jobs.
- Followup testing exposed a second sync issue: frequent UI wakeups canceled an active slow response before it could commit. Wakeups now coalesce into one followup pass while the foreground response finishes. Background prefetch yields to new requests and drains its blocking work before the foreground pass resumes. Metadata-triggered background work uses the same priority rule.
- Story snapshot loading now distinguishes another refresh of the same feed/filter from a different query. Repeated same-query notifications let the active snapshot finish, then process only the newest pending refresh. Changing feed/filter cancels the obsolete cursor and prevents it from publishing. This fixes a starvation regression in the first latest-query implementation.
- Adapter publication applies the same rule to background diffs: finish one useful same-feed batch, then commit the newest queued batch. Paging waits for that commit instead of reporting the previous empty adapter count. Explicit position restoration waits for the newest batch. Feed/grid/style changes invalidate obsolete diffs while retaining the newest pending stories; equivalent folder feed sets use semantic identity regardless of iteration order.
- The first nonempty story batch now starts at the first story instead of retaining the initial full-height footer as its visible anchor. Explicit return-story/configuration restoration still takes priority, and empty intermediate batches retain pending navigation state (`1d9a4e0cd`).
- Folder-collapse geometry now accounts for Android clamping the scroll offset when content becomes shorter. Newly exposed rows above the heading enter from above, and disappearing rows track the same viewport shift (`516ef2024`). Runtime replay passed: `/tmp/newsblur-saved-clamp-fixed-frames.png` keeps the saved-section heading filled as its vertical position moves from 996 to 2040 pixels.
- A later folder-animation fix draws the themed folder surface beneath moving/fading rows, preventing temporary gaps from exposing the darker window background (`f13ce0203`). Runtime replay passed four rapid toggles in each of Light, Dark, Black, and Sepia: `/tmp/newsblur-folder-surface-{light,dark,black,sepia}.mp4` and the corresponding `-frames.png` contact sheets show filled surfaces while retaining row fades.
- Distant internal story navigation now holds the visible page snapshot while the destination viewport prepares, then animates the ready destination (`1fea8e131`). Preparation tracks pause, cancellation, current story, and navigation history. Regression tests and prepared Next/Previous replay pass in all four themes, with the article body already present during the incoming transition. Background/resume during far-page preparation also passes; Back during that preparation remains unverified.
- Rapid navigation exposed a separate race: an older asynchronous Next unread search could overwrite a newer Previous selection. The fix rejects unread-search completions after a newer navigation intent (`984dcc6f3`). Regression tests pass; its rapid three-Next/two-Previous runtime replay is pending.
- Related-story dates have a 6dp gap beside thumbnails (`535fe34fa`), preserving the existing colors, images, and text.
- Coalesced network pages now retain immutable search/filter/order/cutoff snapshots and validate a reading-session generation before insertion. Feed switches and explicit resets invalidate old responses; ordinary same-query read refreshes do not. Validation, insertion, and pagination updates share the existing session-reset lock, so an old response cannot repopulate a newly reset session or be tagged with newly edited search text. Network and HTML parsing remain outside that lock.
- The feed list starts reading its local cache as soon as its view exists, rather than waiting for the sync service's database-ready broadcast. Cached folders, feeds, social feeds, saved counts, and saved searches publish in one Main turn. Empty results complete normally; repeated refreshes coalesce, and a usable prior snapshot stays visible during refresh or a query error. The initial loading pill stays visible until the first feed result arrives. Debug builds log `NB.FeedLoad` counts and elapsed time without account/feed text.
- The latest combined build passed **330 tests with zero failures** plus `assembleDebug` (`/tmp/newsblur-reader-navigation-intent-full.log`, 19s). This includes the rapid-navigation race fix, prepared internal navigation, and the folder-transition background, alongside the earlier sync, cache, typography, menu, and reader fixes. Folder transitions and prepared Next/Previous now pass in all four themes; the newest race fix still needs its runtime replay.

For a read-only update of a parent row with a thumbnail, the verified code path now performs zero title parses, zero thumbnail cancellations/reloads, and zero full content/layout binds. Previously each update performed one of each. Ordinary refresh batches also perform zero layout-manager state saves/restores instead of one save plus one restore. These are source/test-backed work reductions, not inferred frame-rate improvements.

The blocking-work regression measured overlapping primary generations before the fix and a maximum of one afterward, while still running the latest request. Real-app stress evidence is retained in `/tmp/newsblur-android-sync-overlap-before.log`; it includes database waiters, garbage collections freeing 23–32MB in sampled events, and long lock waits. This explains part of the progressively worse pre-fix behavior independently of the host graphics limitations.

The wakeup-burst regression preserves the in-flight page and executes one followup pass for all 20 requests, with one background pass after foreground work catches up. Before/after evidence is in `/tmp/newsblur-sync-coalescing-before.log` and `/tmp/newsblur-sync-coalescing-after.log`. This is a correctness and work-count result; the test does not simulate real network latency or GPU presentation.

The same-query regression submits refreshes every 20ms while a fake snapshot takes 100ms. The first implementation published no snapshot before notifications stopped; the revised runner publishes the active snapshot and coalesces subsequent work. Red/green evidence is in `/tmp/newsblur-story-load-starvation-before.log` and `/tmp/newsblur-story-load-starvation-after.log`. This is a deterministic scheduling test, not an emulator latency measurement.

Page-commit regression coverage includes search mutation, filter/order/cutoff changes, A→B→A navigation, session and pagination resets, same-query refresh coalescing, and reset/insertion serialization. Six of seven tests failed before the guard; all seven pass afterward, alongside nine existing sync/session tests. Evidence is in `/tmp/newsblur-story-page-guard-before.log` and `/tmp/newsblur-story-page-guard-after.log`.

Cold-start baseline video `/tmp/newsblur-cold-baseline.mp4` and contact sheet `/tmp/newsblur-cold-baseline-frames.png` show only social/special sections around four seconds after launch, with account totals 185/20. The regular feeds and totals 19,397/2,046 appear around five seconds; the loading pill is absent during the partial state. Four tests reproduced the underlying cached-load/empty-result/coalescing/publication defects before implementation (`/tmp/newsblur-cached-feed-startup-red.log`). All six startup tests now pass, including active-feed count aggregation and retaining cached results on refresh/error.

Final cold-launch verification passed: `/tmp/newsblur-cold-final.mp4` and `/tmp/newsblur-cold-final-frames.png` show the loading pill until the complete 685-feed/38-folder snapshot arrives, without social-only partial totals. In `/tmp/newsblur-final-cold-log.txt`, PID 8783 logs the first snapshot **906ms after its cache-load request**, while the queued refresh completed 1316ms after its own request. These include query/queue/publication elapsed time and are **not process-launch durations**. `/tmp/newsblur-counts-final-dark.png` confirms formatted totals 19,402 and 2,046.

Offline startup passed as well: `/tmp/newsblur-feed-offline-startup.png` shows the complete cached Main feed list with networking disabled. Networking was restored after the check. Fast story-title fuzz also passed: `/tmp/newsblur-titles-fast-fuzz.mp4` and `/tmp/newsblur-titles-fast-fuzz-end.png` retain full rows and related/matched clusters after six alternating swipes lasting 180, 230, and 350ms. This is visual/state verification, not a quantitative frame-rate measurement.

Some earlier focused after logs intentionally include red tests for subsequent fixes. The final-source build above supersedes those intermediate failures.

## Appearance and reader-entry verification

Verified theme captures cover the following views. They establish appearance and contrast, not a guarantee that every transition is free of flashing. These appearance captures precede the newest prepared internal-navigation and folder-background fixes. Separate newer recordings verify folder transitions and prepared Next/Previous in all four themes.

| Theme | Evidence | Views checked |
| --- | --- | --- |
| Light | `/tmp/newsblur-feed-final-light.png`, `/tmp/newsblur-scroll-evidence/final-ui-matrix-21/light-titles.png`, `/tmp/newsblur-reader-ready-light-transition.png`, `/tmp/newsblur-story-menu-light.png` | Feed list, story titles, story detail, menu |
| Black | `/tmp/newsblur-feed-final-black.png`, `/tmp/newsblur-titles-final-black.png`, `/tmp/newsblur-detail-final-black.png`, `/tmp/newsblur-menu-final-black.png` | Feed list, story titles, story detail, menu |
| Sepia | `/tmp/newsblur-feed-final-sepia-stable.png`, `/tmp/newsblur-scroll-evidence/final-ui-matrix-21/sepia-titles.png`, `/tmp/newsblur-detail-final-sepia.png` | Feed list, story titles, story detail |
| Dark | `/tmp/newsblur-counts-final-dark.png`, `/tmp/newsblur-related-spacing-dark.png`, `/tmp/newsblur-story-menu-dark.png`, final feed/title traces | Account totals, cached startup, scrolling, related-date spacing, menu |

A cold reader entry on the older build reproduced the header appearing before the article body in Black: `/tmp/newsblur-reader-black-entrance-late.png` and `/tmp/newsblur-reader-black-log.txt`. Revised reader readiness passed: `/tmp/newsblur-reader-ready-light-transition.png` shows the article body and image already drawn as the page slides in. That cold preparation took 2668ms, with Loading/Cancel feedback while waiting; this improves presentation rather than making the cold article load instantaneous. Loading/Cancel contrast subsequently passed in Light: `/tmp/newsblur-reader-loading-light-final-frames.png` shows the dark, readable Cancel action.

Header checks at font scales 1.3 and 1.6 passed with action icons unclipped: `/tmp/newsblur-header-large-font-dark.png` and `/tmp/newsblur-header-largest-font-dark.png`. Font scale was restored to 1.0 before final title timing.

The earlier explicit control replay failed backward navigation: `/tmp/newsblur-reader-controls-final.mp4` and `/tmp/newsblur-reader-controls-{0..4}.xml` show Previous with `enabled="false"`. The diagnosed cause was asynchronous history insertion without a subsequent Previous-state refresh, especially when navigating already-read stories. The regression-tested fix (`9884eaec4`) records history and refreshes Previous synchronously while preserving visited-history navigation. Its runtime replay **passed**: `/tmp/newsblur-reader-controls-fixed.mp4` and `/tmp/newsblur-reader-controls-fixed-{0..4}.{xml,png}` show three Next actions through Google Maps → SSD/HDD → Windows battery, then Previous back through SSD/HDD → Google Maps, with Previous enabled. Matching activity/start/end screenshots alone were insufficient; the per-step replay established correct navigation.

The far internal Next replay revealed the header about a second before the article body: `/tmp/newsblur-reader-controls-fixed-forward.png` and `/tmp/newsblur-reader-controls-fixed-forward-late.png`. The activity entrance (`9ec4d6c0c`) already had verified readiness handling. The corresponding internal-jump fix (`1fea8e131`) now passes a five-control Dark replay: `/tmp/newsblur-reader-prepared-controls.mp4` and `/tmp/newsblur-reader-prepared-controls.json` show Next through Lenovo Googlebook → iPhone 18 Pro versus Pixel → Meta headset, then Previous back through the second and first articles. A far 14-position jump, adjacent navigation, and reverse navigation retain an already-drawn article body during the incoming slide.

Recorded request-to-reveal elapsed times were 1798ms for a forward distance of 14 positions, 1709ms for a distance of two, and 1884ms for a reverse distance of two. These include destination preparation; they are not the 180ms slide duration or an app-launch measurement. Roughly 1.6 seconds of cold preparation still precedes the reveal. Review of the original video frames `/tmp/newsblur-reader-original-04.png` (2.911167s), `-05.png` (2.979511s), and `-06.png` (3.233444s) confirms a clean boundary between the outgoing page and the drawn destination. Apparent overlapping old pixels in a derived contact sheet were an extraction artifact, so that sheet is not used as visual proof.

Prepared Next/Previous subsequently passed in Light, Black, and Sepia as well: `/tmp/newsblur-reader-prepared-{light,black,sepia}.mp4`. Review used original decoded frames to check that the incoming article body was painted. Together with the Dark replay, this covers all four themes. The loading pause remains; these recordings do not establish instantaneous loading or 60fps presentation.

Lifecycle replay `/tmp/newsblur-reader-lifecycle.mp4` passed Home during a far 14-position preparation followed by launcher/resume, with the final Lenovo article fully painted. Its final Back action occurred during adjacent navigation, so it does not verify Back while a far-page preparation is pending. That case, the newly fixed rapid-navigation race replay, corrected navigation timing, and matching long-article scrolling measurements remain pending.

## Evidence and remaining measurements

Raw artifacts remain at `/tmp/newsblur-android-profile/`; they are not committed because they contain account-specific screenshots and videos. Reusable collection/query scripts live alongside this report.

- Baseline evidence: `baseline/feed/`, `baseline/titles/`, `baseline/detail/`; quantitative runs: `baseline/feed-timing/`, `baseline/titles-timing/`, `baseline/detail-timing/`.
- Available after evidence: `after/folder-motion/`, `after/feed-timing/`, and the first `after/titles-timing/` run. Query output is saved as `slice-summary.csv` in each analyzed timing directory.
- `final/feed-timing/` is the intermediate sync candidate described above. An earlier detail-after capture interrupted by a force-stop is excluded. Completed feed/title comparisons are `final-coalesced/feed-timing/` and `final-reviewed/titles-timing/`; both precede the latest animation/navigation fixes. `final-reviewed/detail-timing/` remains provisional because Previous was disabled in that recording, and its short articles do not establish long-body scrolling performance. Prepared Next/Previous and folder-background transitions pass in all four themes; Home/resume during far-page preparation also passes. Back during far-page preparation, the rapid-navigation race runtime replay, corrected navigation timing, and a matching long-body scrolling comparison are pending. The completed hardware-layer A/B/A was inconclusive and retained the enabled default. Prior theme appearance, offline startup, fast-scroll fuzz, and reader/folder animation captures are listed above. More repeated measurements with comparable holder/cache state would be needed for a stable speedup estimate.
- Excluded: `/tmp/newsblur-reader-invalid-selection-*`. The selection helper tapped a title obscured by Android navigation instead of entering the reader, so this attempted lifecycle replay does not validate reader behavior. Subsequent replay guards require `FeedReading` before proceeding.
- Excluded: `baseline-speed/feed-timing/`. Under delayed input dispatch, a planned 450ms swipe entered the NewYork folder. Its screenshots and trace mix feed-list and story-list work, so it is not a valid feed-scroll baseline despite having matching ART speed compilation.
- A physical-device run and repeated quiet-host measurements are required before claiming release-level scrolling smoothness or a stable FPS improvement.
