# Cooking App Preview

Status: editable production plan and encoder prepared; no footage encoded or submitted. This is a 20-second demonstration of the actual native app. It is independent of the pending screenshot-layout selection.

## Verified delivery specification

Checked October 16, 2026 against [Apple's App Preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/).

| Target | Portrait export | Landscape alternative |
| --- | --- | --- |
| iPhone 18 Pro Max / large Dynamic Island display | 886 × 1920 | 1920 × 886 |
| 13-inch iPad Pro | 1200 × 1600 | 1600 × 1200 |

Apple accepts 15–30 seconds, up to 500 MB. H.264 uses progressive video, up to High Profile Level 4.0, a maximum 30 fps, and a 10–12 Mbps target. Accepted containers are MP4, MOV, or M4V. ProRes 422 HQ in MOV is another supported option. H.264 audio specifications are stereo AAC, 256 kbps, 44.1 or 48 kHz. The planned output is MP4, H.264 High 4.0, 30 fps, 11 Mbps target, and a silent stereo AAC track at 48 kHz. Including silence is our compatibility choice; Apple's page does not expressly say every silent preview must include audio.

The video uses the accepted preview dimensions, not the native screenshot dimensions. Native portrait footage is proportionally scaled and minimally padded, never stretched.

## Twenty-second edit

Every segment must contain genuine app motion, such as a small scroll or navigation. Record at normal speed. Each five-second selection should include a brief settled beginning and ending. Simple cuts separate the scenes; no slideshow, synthetic scroll, animated screenshot, external photography, phone bezel, or invented interaction is used.

| Time | Real screen and action | Short caption |
| --- | --- | --- |
| 0–5 s | Cooking feed list. Pause on the ten sources, make a short scroll, and settle. | A home for your favorite sources. |
| 5–10 s | Cooking stories. Scroll the actual list/cards enough to reveal another story. | Your daily reading, in one place. |
| 10–15 s | Opened pasta article. Scroll through its real text and photograph, then pause. | Settle into a good read. |
| 15–20 s | Saved Stories. Show the real saved collection and briefly scroll it. | Save a good read for later. |

The last scene also displays “A NewsBlur account is required. Some features require a paid subscription.” Captions and disclosure come directly from the canonical screenshot copy in `../screenshots/copy/<locale>.json`: feeds uses headline 2, stories headline 1, reader headline 3, and saved headline 4. Use a real settled frame around 12 seconds as the poster candidate, then verify that exact frame before selecting it in App Store Connect.

[Apple's preview guidance](https://developer.apple.com/app-store/app-previews/) calls for footage from the app, readable supporting copy, appropriate content rights, and disclosure of login or purchase requirements. This plan uses native NewsBlur captures from the isolated cooking demo: ten fictional sources, twenty original stories, and five licensed food photographs. Full credits and capture instructions are in `clients/ios/MarketingCooking/`. Story content is English demonstration content. It must not be described as a real publisher's article or automatically translated story.

## Files and editing

- `storyboard.json` is the timing, capture-state, and export specification.
- `copy/en.json` contains the editable English captions and disclosure.
- `encode.cjs` reads four supplied video recordings, creates editable ASS captions and a render plan, and only encodes when passed `--execute`.
- `raw/<locale>/<device>-<scene>.mov` is the recommended input convention; the script accepts any existing local video paths. No recordings are currently assumed to exist.
- `exports/<locale>/<device>-cooking-preview.mp4` is the output convention.

The four raw inputs may also point to one continuous recording with different `--starts` offsets. For example, after the footage exists:

```sh
node clients/store/artwork/ios/16.0/preview/encode.cjs \
  --device iphone --locale en \
  --feeds /absolute/path/iphone-feeds.mov \
  --stories /absolute/path/iphone-stories.mov \
  --reader /absolute/path/iphone-reader.mov \
  --saved /absolute/path/iphone-saved.mov \
  --starts 1,1,1,1 \
  --output /absolute/path/iphone-cooking-preview.mp4
```

Without `--execute`, this checks input streams and available duration, and writes only the edit plan and ASS subtitle file beside the requested output. It does not run an encoder. Review the chosen five-second intervals before adding `--execute`. If the actual footage requires a different rhythm, `--durations 3,5,7,5` changes the four scene lengths while preserving a 20-second total; every interval must be at least two seconds. Captions follow those actual edit boundaries. Never stretch, repeat, or synthesize footage to fill an interval. Existing output files are not overwritten. Encoding runs one output at a time with bounded decoder/encoder/filter threads. Do not run parallel encodes on the shared Mac.

Captions use libass with font fallback for complex scripts. The installed FFmpeg exposes both `ass` and `subtitles` filters. A supported system font is selected by script; visual checking is still required, especially for Arabic, Hebrew, Devanagari, Thai, and CJK. The script rejects untranslated locale fallback: each locale requires its own copy JSON and the caller must supply the corresponding native-language footage. The original English story content can remain visible inside the localized app.

## Localization and review

Produce one iPhone and one iPad preview for each of the 21 supported locales once the capture workflow supplies native UI recordings and reviewed caption files. `copy/<locale>.json` must have exactly `feeds`, `stories`, `reader`, `saved`, and `disclosure`. Record translation review separately; filenames alone do not prove a translated interface.

The script checks technical output properties and writes a probe report. It cannot prove useful motion, correct language, missing glyphs, readable captions, clean scene cuts, settled sync state, lack of personal data, or a good poster frame. Review the entire actual video before upload. Verify processing and App Review submission independently; a local valid video is not a submitted preview.
