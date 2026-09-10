# Scrolling performance

`ReaderPerformance.swift` instruments the real feed table, story table, and story web view when the app launches with `NB_SCROLL_PERFORMANCE=1`. Ordinary launches keep the original method implementations and do not run the recorder.

The measurements distinguish cell configuration, drawing, story heights, table reloads, scroll-to-read handling, and detail gradient updates. `draw.story` measures the cell container; `draw.story.content` measures the content drawing. Neither includes the GPU's eventual presentation time.

The `frame.*` events measure time between main-thread display-link callbacks while the corresponding scroll view is tracking or decelerating. The summary counts intervals longer than 1.5 times that callback's requested frame interval. These are main-thread frame gaps, not Instruments animation-hitch metrics or a physical-device frame-rate guarantee.

## Repeating a run

Reuse the booted simulator returned by `python3 clients/ios/run_ios.py list`. The September 2026 audit uses NewsBlur Alpha on iPhone 17e, iOS 26.5. Keep the same build configuration, device, view, starting position, preferences, gesture seed, and gesture count when comparing changes. Do not build or run tests concurrently with measurements.

Build the Alpha app and regression host from `clients/ios`:

```sh
xcodebuild -project NewsBlur.xcodeproj -scheme 'NewsBlur Alpha' \
  -configuration Release -destination "platform=iOS Simulator,id=$IOS_SIM_UDID" \
  -derivedDataPath /tmp/newsblur-scroll-derived \
  CODE_SIGNING_ALLOWED=NO ENABLE_TESTABILITY=YES ONLY_ACTIVE_ARCH=YES build-for-testing
```

Install and launch using the helper, preserving app data and the account session:

```sh
export IOS_BUNDLE_ID=com.newsblur.NB-Alpha
export IOS_APP_PATH='/tmp/newsblur-scroll-derived/Build/Products/Release-iphonesimulator/NB Alpha.app'
export SIMCTL_CHILD_NB_SCROLL_PERFORMANCE=1
python3 clients/ios/run_ios.py --udid "$IOS_SIM_UDID" terminate install launch
```

Navigate to the desired view, then record the scrolling:

```sh
python3 clients/ios/run_ios.py --udid "$IOS_SIM_UDID" \
  capture:/tmp/newsblur-scroll-evidence/example \
  fuzz:417,24 sleep:3 \
  screenshot:/tmp/newsblur-scroll-evidence/example/end.png
swift clients/ios/Performance/summarize.swift /tmp/newsblur-scroll-evidence/example
```

The seeded gestures alternate speeds and periodically reverse direction. They use portrait iPhone content coordinates and never tap a read-state action. Keep mark-as-read-on-scroll enabled for the story test; it marks the stories passed during the run. Never use mark-all-as-read to prepare data.

The opt-in `state.stories` event records loaded and visible story counts once per second. Use it to verify that a long forward/reverse run exceeds the preview cache's 512-story capacity. These events contain counts and timestamps only.

`coldcapture:<directory>` records an app restart without deleting its data. A `checkpoint:<name>` before a navigation tap records a timestamp for comparing the first subsequent cell/header measurement with the video. Capture directories contain `scroll.mp4`, symbolized `cpu.txt` samples, `session.json`, and a copy of the app's `measurements.jsonl`. The summary filters events to the recorded session. The app measurement file contains timings, not story content; videos naturally show the account's visible stories.

Set `IOS_CAPTURE_CPU=0` to repeat a video capture without attaching the CPU sampler. Use this control when measuring startup, where profiler attachment can affect the result. `launch.probes_ready`, `launch.prepare_views`, `render.stories`, and `detail.prepare` help locate preparation costs in subsequent builds. A checkpoint-to-first-cell interval includes automation dispatch and cell configuration. Story cell configuration also includes the loading-bar cell, so use the first `draw.story.content` event when comparing time to story content. Neither measurement establishes that every image or the full web page has finished drawing. Exclude outgoing-view draws by repeating the same opening and checking the video.

CPU sampling uses macOS `sample` against the actual simulator app PID. Optional `IOS_USE_XCTRACE=1` also requests a Time Profiler trace. The Xcode/iOS runtime combination used for this audit stalled simulator Instruments attachment with overlapping-image mapping errors, so the audit relies on the symbolized samples and display-link measurements. Video frame counts alone are not treated as app FPS.

Run the dedicated Alpha regressions after building:

```sh
xcodebuild -project NewsBlur.xcodeproj -scheme 'NewsBlur Alpha' \
  -configuration Release -destination "platform=iOS Simulator,id=$IOS_SIM_UDID" \
  -derivedDataPath /tmp/newsblur-scroll-derived -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO ENABLE_TESTABILITY=YES ONLY_ACTIVE_ARCH=YES test-without-building
```

The Alpha regression host is separate from the production NewsBlur app, allowing both apps to remain installed. The tests cover cached image fidelity, icon edits and appearance changes, favicon warm hits and misses, native/SwiftUI layout routing, scroll read-state updates, and detail toolbar/adjacent-page synchronization.
