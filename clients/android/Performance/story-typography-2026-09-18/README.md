# Android story typography and v15 regression checks

Device: Samsung Galaxy S22 (SM-S901U1), Android 16, existing account/session retained. Branch: `android-add-discover-sites`. These are development changes after the tagged 15.0.3 release; no version bump or Play upload.

## Report and reproduction

[Original report and followup](https://forum.newsblur.com/t/android-v15-regressions/13838/2): v15.0.0 from F-Droid on a Pixel 8a running GrapheneOS. The subsequent user direction was to follow iOS/web typography, rather than implement every suggested change literally.

- **Feed labels/headlines:** reproduced on the current Android branch at XL in Compact spacing. The feed label occupied y=258–334 while the headline started at y=312. The headline was anchored beneath an 18dp favicon instead of the scalable feed label. Both also used bold text and the same heading color. See [before](overlap-before.png).
- **Save/unsave long press:** the handler already supported toggling, but the preferences omitted that choice. A failing choice test reproduced the omission. `04fff8203` adds it while retaining explicit Save and Share selections.
- **Default long press:** the default is already Menu in `Android_15.0.3`; explicitly selected gestures remain authoritative. Preference regression tests cover both cases.
- **Intermittent delayed opening:** native reader entrance already shipped in `Android_15.0.3`. Two sampled Unread/Oldest openings on the current Samsung build entered at 463ms and 312ms from reader preparation start. This is not input-to-display latency or proof against the reporter's intermittent GrapheneOS case. Automatic read marking was disabled during these checks to preserve account read state.

## Changes

`8faa80ddf` reserves the feed label's measured height, separates feed/headline colors, imports the same Whitney Medium font used by iOS, and keeps date/author within a measured horizontal text column. The author uses the remaining width and truncates safely beside long dates and thumbnails.

The regular-row typography follows `clients/ios/Classes/FeedDetailTableCell.m` on `ios-add-discover-sites`:

| Size | Feed label | Headline | Preview | Date/author |
| --- | ---: | ---: | ---: | ---: |
| XS | 11sp | 12sp | 10sp | 11sp |
| S | 13sp | 14sp | 12sp | 11sp |
| M | 14sp | 15sp | 13sp | 11sp |
| L | 16sp | 17sp | 15sp | 11sp |
| XL | 18sp | 19sp | 17sp | 11sp |

Android system font scaling still applies. Legacy XXL remains supported at 24/25/23/11sp. Feed-list and story-list preferences remain linked; article font size remains independent. Read feed labels use Whitney Book, unread labels and headlines use Medium. Theme colors remain centralized in `StoryRowPalette.kt`.

`78ce27014` balances multiline headlines without automatic hyphenation, following the web's preference for well-distributed title lines. At Medium, the sample title ending in `C/C++` no longer leaves a lone `+` on a third line. See [before](wrapping-before.png) and [after](light-compact-m-portrait.png).

## Automated validation

The initial layout-anchor and missing-gesture tests both failed before implementation. The completed suite has **578 tests, zero failures/errors/skips**, across 127 suites. The final resource-only wrapping change rebuilt and installed successfully with the same unit reports up to date.

```sh
env JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
  ./gradlew :app:testDebugUnitTest :app:installDebug
```

No instrumentation APK, app-data reset, or new emulator was used. Device screenshots and layout bounds provide the rendering checks beyond the JVM layout/typography tests.

## Samsung rendering checks

The final source build (`78ce27014`) was installed on the Samsung. The [core matrix](core-matrix.csv) covers **80 captures**: all five sizes, both Compact and Comfortable, Light/Dark/Black/Sepia, and portrait/landscape. Its 1,095 layout-bound comparisons found no overlaps. Each capture asserts the actual orientation after launch; representative images were also inspected visually across sizes, spacing modes, themes, and rotations.

The [supplementary matrix](supplementary-matrix.csv) adds **46 captures and 498 comparisons**, also without overlap failures:

- Left/right/small/large/no thumbnails, and missing/small/large previews.
- Single-feed and folder rows, saved stories with missing previews/authors and long dates, and the All stories filter.
- Grid layouts and the legacy XXL setting. Narrow three-column grids still truncate or wrap long words aggressively at XL; grid column sizing was not redesigned in this change.
- XL with Android system font scale at 130%, in both spacing modes and both orientations. See [Compact](system-font-130-xl-compact-portrait.png) and [Comfortable](system-font-130-xl-comfortable-portrait.png).

Total: **126 captures, 1,593 bounds comparisons, zero overlap failures**. These are sampled visible rows, not exhaustive content coverage or validation on the reporter's Pixel/GrapheneOS device. The floating footer intentionally overlays the scrolling list.

The actual story long-press chooser shows [Save / unsave alongside Save story](longpress-choices.png), with Show actions still selected. No gesture preference was changed through the chooser.

Fifteen temporarily changed preferences were restored and compared with their original values. System font scale was restored to 1.0 and automatic rotation enabled with portrait orientation. The app remains running with the existing login. An out-of-band QA command briefly wrote a string instead of a float for list size, causing a startup ClassCastException; the QA value was corrected, and the original preference was restored. The rendering matrix itself had no NewsBlur crashes, and the post-restoration crash check was clear.

## Forum screenshot set

Six original 1080×2340 PNGs in the requested Black theme, using the same story content:

| Size | Compact | Comfortable |
| --- | --- | --- |
| XS | [Screenshot](forum/01-xs-compact.png) | [Screenshot](forum/02-xs-comfortable.png) |
| M | [Screenshot](forum/03-m-compact.png) | [Screenshot](forum/04-m-comfortable.png) |
| XL | [Screenshot](forum/05-xl-compact.png) | [Screenshot](forum/06-xl-comfortable.png) |

The same six files are available locally in `~/Downloads/NewsBlur-Android-Story-Typography/` and `~/Downloads/NewsBlur-Android-Story-Typography.zip`. Nothing was posted to the forum.
