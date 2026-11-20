# Reader entrance before article rendering

Samsung Galaxy S22 (SM-S901U1, Android 16), existing login preserved. Implementation: `d40f0748a` on `android-add-discover-sites`. No version bump or Play upload for this followup.

## Behavior

The reader enters when the selected story's native title has been bound and laid out. The article independently fades in over 140 ms after its WebView visual-state callback. The tapped story keeps its selection highlight until covered; its existing return fade remains intact.

The hidden article remains drawable so Chromium can produce its first frame. Its accessibility subtree is withheld until the fade finishes. Related stories, actions, and comments remain hidden during preparation, avoiding a transient footer directly beneath the title before the article acquires its height. Existing theme backgrounds are used.

The initial automatic mark-read delay and reading-time tracking begin only after article visibility. Native callbacks recheck target identity and lifecycle; canceled/backgrounded/replaced fades cannot report stale visibility. Prepared Next-story transitions continue to wait for complete article presentation.

## Timing and recordings

Same Blogs-folder story, “How To Write With An LLM,” recorded before and after:

| Measurement | Before | Final build |
| --- | --- | --- |
| Repeat opening: preparation start to entrance animation | 889 ms | 189 ms |
| Repeat opening: preparation start to article visual callback | 882 ms | 854 ms |
| First reader opening after final app restart | — | 374 ms |

These debug measurements start inside `Reading.onCreate`, after root inflation. They are not full input-to-display latency, network benchmarks, or a guarantee for every story. The article's own rendering still takes time; it no longer delays the title and controls. The final repeat article fade completed at approximately 1000 ms from that preparation start.

- [Before](before.mp4)
- [After: early native entrance, article fade, no transient related-story section](after.mp4)
- [Dark landscape](dark-landscape.mp4)
- [Black portrait](black-portrait.png)
- [Sepia landscape](sepia-landscape.png)

## Validation

The initial native-entrance regression failed before implementation. A second regression reproduced the footer appearing before the article. Both pass after their fixes.

```sh
env JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew :app:testDebugUnitTest :app:installDebug
```

556 unit tests passed, zero failures/errors/skips. Installed on the Samsung without instrumentation or account reset.

Recorded and visually inspected opening/fading in light and black portrait, dark and sepia landscape. All four checks also verified the actual story-title list after Back and its settled row background: light `(244,244,244)`, dark `(79,79,79)`, black `(0,0,0)`, sepia `(243,226,203)`.

Early Back during preparation, Home/resume during loading, rotation during loading, and Next-story navigation were exercised on the device. Home/resume and rotation were repeated after the footer refinement. No NewsBlur crash-buffer entries were observed. An unrelated UIAutomator process failed once during automation; subsequent dumps and checks completed.

Original AUTO theme, font, mark-on-scroll, confirmation preference, and automatic rotation were restored. The final build remains installed with Blogs open for manual testing.
