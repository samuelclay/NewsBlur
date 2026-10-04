# NewsBlur 15 mobile media

The phone frames are model-specific transparent PNGs from Mobile FIRST:

- [Apple iPhone 17](https://www.webmobilefirst.com/en/mockups/apple-iphone-17-2025/)
- [Samsung Galaxy S22](https://www.webmobilefirst.com/en/mockups/samsung-galaxy-s22-2022/)

Downloaded September 23, 2026. The source pages permit personal and commercial use, modification, and cropping without attribution. Resale or redistribution of the frame alone is prohibited. These frames are used here to present the NewsBlur interface. Both source PNGs are 388 × 800 pixels and are retained unchanged.

`mobile-release.css` positions the media beneath the frames using the measured transparent screen bounds. The camera cutouts, chassis, and buttons come from the source frame artwork. Captures preserve their aspect ratio.

Android recordings were captured on the existing Samsung Galaxy S22, running NewsBlur 15.0.4, on September 23, 2026. The five clips show story-list scrolling and reader navigation, article scrolling with floating controls hiding and returning, image opening/zoom/dismissal, Quick Add opening and discovery navigation, and opening a discovery story and returning to the highlighted preview. The MP4 files use H.264 at 720 × 1560, 60 fps, without audio, at the original interaction speed. Still posters are fallbacks; animations are real screen recordings.

The two tablet clips were captured on September 30, 2026 on a Samsung Galaxy Tab A8 (SM-X200) in landscape, running a debug build from main that includes the tablet layout and image long press. `android-15-tablet.mp4` shows picking a feed from the slide-over feed list, opening a story, paging to another, and switching sites. `android-15-image-actions.mp4` shows long pressing an xkcd comic for its hover text and saving it. Both use the light theme with Show taps turned on, and they are 1440 × 900 H.264 at 60 fps, without audio, at the recorded speed. They are shown without a device frame because only exact device frames are used and there is no tablet frame.

The five iOS recordings were captured on September 23 on the already booted iPhone 17e simulator, using its signed-in NewsBlur app. They show story-list scrolling and reader navigation, article scrolling with floating controls, image opening and swipe dismissal, the Quick Add sheet, and discovery preview navigation with the highlighted return state. The screen captures are presented inside the iPhone 17 frame. These H.264 clips are 720 × 1558 at 60 fps, without audio. Idle setup time is trimmed and final frames are briefly held; gestures and transitions play at their recorded speed. Posters come from the same capture session.

The iOS story-list clip (`ios-15-reader.mp4`, poster `ios-15-story-list`) was reshot on October 2 on the same iPhone 17e simulator because the first take juddered: idb delivered drag touches at about 30Hz, so the list moved on two frames out of three. The reshoot uses quick flicks so the motion is the app's own momentum scrolling, and the recorder's duplicate captures are dropped so each rendered frame gets its own 60fps slot instead of being resampled by its jittery timestamp. Four frames the loaded simulator failed to draw were rebuilt from their neighbors: one mid-scroll frame by moving the list halfway between the frames around it, and three frames of the back transition by moving the reader and story list layers halfway. Everything else is the recording as captured.

The iOS Quick Add clip (`ios-15-add-site.mp4`, poster `ios-15-add-site`) was reshot on October 3 on the same simulator with the feed list in Unread mode rather than All, so only sites with unread stories sit behind the sheet. It is the recording as captured, with duplicate captures dropped the same way.

The Android Add Site clip (`android-15-add-site.mp4`, poster `android-15-add-site`) was reshot on October 3 on the same Galaxy S22 running NewsBlur 15.0.4, so it continues past the Popular tap until the results load. The feed list is in Unread mode. About three seconds of the loading spinner were cut at a point where the spinner frames match, and a still stretch of the loaded results was shortened; the motion is as recorded.

Posters are resized to 720 pixels wide and encoded as lossless WebP for the pages and feeds. Original PNG captures are retained for provenance and social previews. Video preload is disabled; playback starts when a clip becomes visible.

The player only starts clips when visible, pauses offscreen, and keeps clips still when reduced motion is on, showing the browser's own video controls so a clip can still be played by hand. Without JavaScript, native video controls remain available. Decorative phone frames are CSS pseudo-elements, so they do not appear as standalone images in feed readers.
