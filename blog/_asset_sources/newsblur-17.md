# NewsBlur 17 launch media

Made November 16 to 18, 2026 for the NewsBlur 17 posts: `_posts/2026-11-22-newsblur-17-motion.md`, `_posts/2026-11-20-mobile-web-version-of-newsblur.md`, and `_posts/2026-11-19-podcasts-in-listen-and-listen-over-your-music.md`.

## Recordings

Every clip is a real screen recording, on Sam's own account (samuel, 710 sites) against production data, at the speed it was recorded.

- **Web:** Chrome 157 with a 1440 × 900 viewport, on staging.newsblur.com running main at `4f6f602998` (staging uses the production database). Recorded with `screencapture -V` on the viewport region at 2880 × 1800.
- **Mac:** NB Alpha 17.0 (build 357), a Debug Mac Catalyst build of main signed ad hoc, in a 1440 × 900 window in the Light theme. Recorded with `screencapture -V` at 2880 × 1800.
- **iPhone:** NewsBlur 17.0, a Debug build of main on the iPhone 17 simulator (iOS 27.2), recorded with `xcrun simctl io recordVideo --codec=h264` at 1206 × 2622, status bar set to 9:41.
- **Android:** NewsBlur 17.0, a debug build of main on the Galaxy S22, recorded with `adb shell screenrecord` at 1080 × 2340.

Each recording was resampled to a constant 60 fps before use. Stories opened during the takes were marked unread again afterwards.

## Composed clips

`web-feed-list-load.mp4` (1600 × 760, 10.3 s) was drawn frame by frame in headless Chrome from an HTML stage (the same background as the Listen images), then encoded as H.264 at 60 fps with no audio.

- The load comparison is a reload of newsblur.com (before: production, which doesn't have the cached feed list yet) beside staging (now), both navigating at the same moment. Each clock stops on the first frame the feed list appears: 6.6 s and 0.6 s. Separate timed reloads gave 6.5 to 7.2 s before and 0.67 to 0.69 s after a first visit.

`motion-folder-and-story.mp4` (720 × 1566, 4.35 s) was recorded November 18 on the iPhone 17 simulator, running NewsBlur 17.0 signed in to production, after opening Cooking once so its stories were cached. It taps Cooking, then the folder's first story. Every animation plays at its recorded speed, including the 0.2 s empty list after the push. The only cut is 0.9 s of unchanged list while the script waited to tap the story; the clip holds its last frame for 1 s before looping. Touch dots mark the two taps. It plays in the post's iPhone frame.

`web-phone-layout.mp4` (720 × 1566, 12.8 s) is Safari on the iPhone 17 simulator signed in to staging.newsblur.com, with touch dots drawn where each tap and swipe was sent. It plays in the post's iPhone frame.

## Stills

- `reduce-motion.webp`: crops of the web Preferences dialog (staging), the iPhone simulator's Preferences, and the Android Black theme capture from PR #2203, on the same stage.
- `mac-17-reader-frame.webp`: the NB Alpha window with its shadow, on the blog background.
- `web-phone-folder-sheet.webp`: a long press on a folder in Safari on the simulator.
- `android-podcast-card.webp` and `listen-music-balance.webp`: Galaxy S22 and iOS captures from PRs #2193 and #2202.
- `listen-voice-rotation.webp`: the web voice picker with two voices in rotation, from PR #2216.
