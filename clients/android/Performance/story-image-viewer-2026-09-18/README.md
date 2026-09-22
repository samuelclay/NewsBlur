# Android story image viewer

Implementation: `702e56a3b`, formatting: `5ff7eb708`, on `android-add-discover-sites`. The branch was rebased onto the concurrent main merge (`a8b39e740`) before pushing. No app version bump or Play Store submission was made for this feature.

Reference: `clients/ios/Classes/StoryImageViewerController.swift` and `clients/ios/static/storyDetailView.js` on the local `ios-add-discover-sites` branch (`3b0a11367` at inspection).

## Behavior

- Tapping an article image opens a native fullscreen overlay with a black backdrop and a floating X. Images inside links open the viewer without also navigating to the link.
- Double tap zooms to 3× around the tapped point, or returns to fit. Pinch zoom and bounded panning are supported.
- A single tap while zoomed returns to fit, as requested. A single tap while fitted leaves the viewer open.
- At fit, a drag in any direction moves and slightly shrinks the image while revealing the reader underneath. A sufficient distance or deliberate flick dismisses; a short drag springs back. While zoomed, a drag pans without dismissing.
- X and Android Back close the image. Rotation refits it to the new window. Closing returns to the existing article WebView rather than rebuilding the reader.
- A bounded snapshot appears during loading. The full bitmap is decoded off the main thread, with a maximum 4096-pixel edge. Cached reader images and embedded image data work without network access. A failed load retains the preview and offers Retry.

The image bridge is restricted to the reader's app-assets origin and the main frame, using [AndroidX WebView's origin-scoped message listener](https://developer.android.com/reference/androidx/webkit/WebViewCompat#addWebMessageListener(android.webkit.WebView,java.lang.String,java.util.Set%3Cjava.lang.String%3E,androidx.webkit.WebViewCompat.WebMessageListener)). Document generations reject stale messages; numeric image tokens keep return-rectangle queries bounded to the selected image. Native loading accepts web/image-data URLs and confined image-cache paths, not arbitrary local files. Older WebViews without the messaging feature retain their existing image/link behavior.

## Automated checks

**594 JVM tests across 129 suites passed**, including 13 new image geometry/source tests. These cover aspect-preserving fit, no enlargement of small images beyond their natural display size, zoom focal point, pan limits, returning to fit after panning, rotation reset, zoom limits, all dismissal directions, flick thresholds, malformed metadata, stale/injectable tokens, and confined cache paths.

```sh
cd clients/android/NewsBlur
env JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew :app:testDebugUnitTest
node app/src/test/js/storyImageViewer.test.cjs
```

The JavaScript test executes the actual image bridge and checks `currentSrc`, link interception, document generations, protected icons, data/cache URLs, unsupported sources, and graceful absence of the native bridge.

## Samsung checks

Physical Samsung Galaxy S22 (SM-S901U1), Android 16. Installed with `:app:installDebug`, retaining the account and app data. No instrumentation APK was installed. Automatic read marking was temporarily disabled to avoid changing account read state during repeated navigation.

- A real article image opened with a physical tap. [Fitted](black-fitted.png), [double-tap zoom](black-double-zoom.png), and [single-tap reset](black-single-tap-fit.png). After panning and zooming, single-tap reset produced pixel-identical output to the fitted image.
- Injected native two-pointer touch events verified pinch zoom. A one-finger drag while zoomed panned and kept the viewer open.
- Up, down, left, right, and diagonal swipes dismissed. A short drag stayed open and returned to fit. Both X and Android Back returned to the article.
- Rotation while open kept the viewer visible and refitted the image. [Landscape](black-landscape-fit.png). Zoom, tap reset, and dismissal also worked in landscape.
- A linked [cached image opened with Wi-Fi and mobile data disabled](cached-offline-linked-image.png). Deleting only the temporary QA cache file produced the [load error](cache-evicted-error.png); restoring that file and tapping Retry [loaded the image](cache-retry-success.png), still offline.
- Temporary in-memory DOM fixtures covered 1200×800, 1600×220, 250×1400, and 40×30 embedded PNGs. [Panorama](data-panorama-fit.png) and [small image](data-small-fit.png). The original article DOM was restored; no story database rows or server content were changed.
- Light, Dark, Black, and Sepia all passed opening, double-tap zoom/reset, rotation with the viewer open, and dismissal. The backdrop deliberately stays black in every theme, matching iOS. Return screenshots: [Light](light-article-return.png), [Dark](dark-article-return.png), [Sepia](sepia-article-return.png). [Viewer in landscape from Sepia](sepia-landscape.png). Double-tap reset produced pixel-identical fitted captures in Light, Dark, and Sepia.

[Device demo](image-viewer-demo.mp4): opening a story image, double-tap zoom, panning, single-tap reset, pinch zoom, and diagonal dismissal. A copy is in `~/Downloads/NewsBlur-Android-Image-Viewer.mp4`.

The original theme and both read-marking preferences were restored and compared with their saved values. Portrait and automatic rotation were restored, Wi-Fi and mobile data are enabled as before, and the temporary cache file, device gesture helper, recording, and adb port forwarding were removed. The app remains installed and logged in. The crash buffer contained no new crashes during this feature's device checks.

`image-fixtures.js` documents the temporary DOM fixtures. `ImageTouch.java` is an adb-shell gesture helper compiled with the Android SDK and run through `app_process`; it does not install an APK or instrumentation package.

The first automation attempt encountered a UIAutomator idle timeout after closing the landscape viewer, and a separate fixture lookup assumed WebViews were taller than 500 pixels. The automation was corrected to retry fresh hierarchy reads and accept short documents. These were harness failures, not image-viewer crashes.

## Status bar follow-up

The initial viewer hid both system bars, changing the reader's available insets. The follow-up included in Android 15.0.4 keeps both bars visible and uses light icons against the black backdrop, matching the updated iOS status bar behavior.

`test_system_bars.rb` failed on the previous Samsung build with `FAIL: statusBars hidden while image viewer is open`. After installing the fix, it passed in portrait and landscape for Light, Dark, Black, and Sepia. Run it with an image already open:

```sh
ruby clients/android/Performance/story-image-viewer-2026-09-18/test_system_bars.rb <adb-serial>
```

For the same Neowin article in each theme, the native WebView position and dimensions and the DOM viewport, body, and image rectangles were identical before opening, while the viewer was open, and after dismissal. Double-tap zoom, single-tap reset, and Android Back also passed. The 13 image JVM tests and JavaScript image bridge suite passed. Local screenshots and geometry measurements are in `/tmp/image-status-proof/`.
