# Android promotional video

`encode.cjs` prepares a 28-second, 1920 × 1080, 30 fps silent H.264 video for each of the 21 supported languages. The eight cuts show the actual phone interface followed by the actual tablet interface. Each 3.5-second cut uses real recorded motion at normal speed. When Android omits unchanged ending frames, an explicitly recorded hold of the last real frame fills the remaining cut. No motion is generated from still images, and the pipeline does not simulate taps, scrolling, zooms or transitions.

## Inputs and composition

Supply these eight real recordings for each language:

```
../captures/footage/<language>/phone-feeds.mp4
../captures/footage/<language>/phone-stories.mp4
../captures/footage/<language>/phone-reader.mp4
../captures/footage/<language>/phone-saved.mp4
../captures/footage/<language>/tablet10-feeds.mp4
../captures/footage/<language>/tablet10-stories.mp4
../captures/footage/<language>/tablet10-reader.mp4
../captures/footage/<language>/tablet10-saved.mp4
```

Capture approximately five usable seconds per scene. The default selects the first 3.5 seconds; `--starts` selects eight explicit offsets in the order above. Inputs must provide at least 1.5 seconds and 30 genuine recorded frames. A shorter-than-3.5-second interval receives a final-frame hold; its exact duration is recorded in the plan. The script rejects missing recordings, shorter intervals, implausible dimensions, image-like inputs and unresolved video-rotation metadata.

The complete native image is fitted within 1800 × 864 without cropping or distorting the screen. Sage fills unused space, including the sides of portrait footage. Captions occupy the cream band above the app. The account/paid-feature disclosure appears in the bottom band during the final seven seconds. The app remains visible throughout all 28 seconds. The video is intentionally silent and remains understandable during muted autoplay.

Localized copy lives in `copy/<language>.json`. Captions are burned into the video using libass complex-script shaping, with fonts for Arabic, Hebrew, Devanagari, Thai, Japanese, Korean and both Chinese scripts. An accompanying SRT provides accessible subtitle text for YouTube. Brand names and the actual demo stories are not machine-rewritten by this encoder.

## Render

```sh
node clients/store/artwork/android/16.0/preview/encode.cjs --locale en
node clients/store/artwork/android/16.0/preview/encode.cjs --locale en --execute
```

The first command only validates source media and creates an editable render plan/caption files. The second encodes the video. Optional arguments are `--starts 0,0,0,0,0,0,0,0` and `--output /absolute/new-file.mp4`. Existing videos are never overwritten.

Default output: `exports/<language>/newsblur-android-16.0.mp4`. The adjacent `newsblur-android-16.0-edit/` directory contains:

- `render-plan.json`: selected source intervals, complete source probes/checksums, encoder/copy hashes, exact command and final technical checks.
- `captions.ass` and `captions.srt`: localized visual and accessible captions.
- `review-scene-1.png` through `review-scene-8.png`: midpoint frames for visual review.

Encoding validates H.264 High profile/level 4.1, 1920 × 1080, YUV420P, 30 fps, 840 frames, 28 seconds and no audio. It rechecks every source hash after encoding and records the output checksum. Full playback review is required in addition to the eight still frames. Do not mark a prepared plan or a technically valid encode as visually approved, uploaded or live.

## Google Play and YouTube checks

[Google's preview-video guidance](https://support.google.com/googleplay/android-developer/answer/9866151) was checked October 17, 2026. Play accepts a plain YouTube video URL per localized listing. The uploaded video must be public or unlisted, embeddable, free of ads and not age-restricted. Monetization claims can still introduce ads and must be checked. The authorized destination channel must be verified before uploading.

Google recommends real app use early, most of the duration showing the experience, concise videos, localized UI/copy and legible captions. This edit shows native Android content immediately and throughout all 28 seconds, within the 30-second autoplay window, and avoids store badges, ranking claims and download prompts. Silence is intentional; captions carry the message.

After encoding, review every localized video's complete playback and text. After YouTube processing, verify playback, visibility, embedding, age/advertising status, subtitle language and the actual watch URL. Only then attach the locale's URL to Play, preserving all other listing metadata and pending changes. Read back each persisted Play URL. YouTube upload and Play listing persistence are separate completion states.

English validation: authentic eight-clip encode passed duration, codec, dimensions, frame count, source hashes and full ffmpeg decoding. All eight scene midpoint frames were visually checked; complete player playback remains a separate review step. Missing recordings and insufficient genuine footage fail closed.
