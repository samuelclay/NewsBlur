# Preserve reader toolbar state across stories

The reader's story-selection callback called `enableOverlays()`, which expanded the header even after scrolling had hidden it. `before-hidden.png` and `before-story-change-revealed.png` show the reproduced issue while swiping between stories in Bloglets.

`Reading.kt` now lets scroll position control toolbar visibility independently of story selection. Next, Previous, and paging do not expand or collapse it. Exiting fullscreen video restores the current control opacity without expanding the header. `ItemsList.java` carries the hidden state through the reader result and passes it to the next selected title, including saved-instance restoration. A fresh story-list session starts with the header visible. `UIUtils.java` and `FeedItemsList.kt` propagate the state through both related-story launch routes.

A second live regression, shown in `before-title-reselection.png`, exposed an initialization race: feed metadata configured the toolbar scroll flags after the first layout had already consumed its hidden state. `Reading.kt` now establishes the scroll range synchronously before applying the initial collapse.

The existing 30dp reverse-scroll threshold, proportional reveal, themed status-bar background, and edge-back gesture remain in place.

## Validation

- The regression test first failed because three story-selection callbacks called `enableOverlays()` three times.
- After the fix, all 48 reader/session/toolbar tests passed.
- Debug and Alpha APKs built successfully.
- Installed Debug over the existing emulator app, retaining Samuel's session.

Build/test command, from `clients/android/NewsBlur`:

```sh
env JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew \
  :app:assembleDebug :app:assembleAlpha :app:testDebugUnitTest \
  --tests 'com.newsblur.activity.Reading*Test' \
  --tests 'com.newsblur.activity.ItemsListToolbarSessionTest' \
  --tests 'com.newsblur.activity.FeedItemsListToolbarLaunchTest' \
  --tests 'com.newsblur.view.ReaderToolbarRevealGateTest'
```

## Emulator checks

Samuel remained logged in on the existing Pixel 5 API 35 image. Light, dark, black, and sepia passed visible Next, hidden Next/Previous, hidden title reselection, pull-down reveal, and visible title reselection. The header and bottom controls kept the correct state, and the fixed status-bar background matched each theme.

Forward paging by swipe advanced successfully in light and dark. In black and sepia, the injected horizontal swipe did not advance the story, although the toolbar remained hidden; these attempts are not counted as successful paging tests. A read-only audit found no persistent pager-disable flag or normal-path retained transition overlay. This separate swipe behavior needs further runtime diagnosis. Related-story state propagation and fullscreen control restoration have focused unit coverage, not an additional live run here.

The emulator debugging connection froze during the first installation attempts. Restarting the same device image with four cores, software rendering, and no window allowed the UI checks to finish. These are functional checks, not new scrolling-performance measurements.
