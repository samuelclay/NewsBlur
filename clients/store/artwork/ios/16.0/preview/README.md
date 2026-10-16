# Cooking App Preview

Status: English iPhone and iPad previews are encoded from real native recordings and pass technical checks. The edits have been inspected using contact sheets at two frames per second and larger frames around cuts, captions and the ending. Both played through in QuickTime at normal speed, with UI observations of the beginning, reader progression and Saved Stories ending. Store placement, processing and submission are tracked separately by the release coordinator. The default storyboard is a 20-second demonstration of the actual native app; final edits may run 15–30 seconds to match usable footage. The screenshot direction is approved as 01, Sage panels.

## Verified delivery specification

Checked October 16, 2026 against [Apple's App Preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/).

| Target | Portrait export | Landscape alternative |
| --- | --- | --- |
| iPhone 18 Pro Max / large Dynamic Island display | 886 × 1920 | 1920 × 886 |
| 13-inch iPad Pro | 1200 × 1600 | 1600 × 1200 |

Apple accepts 15–30 seconds, up to 500 MB. H.264 uses progressive video, up to High Profile Level 4.0, a maximum 30 fps, and a 10–12 Mbps target. Accepted containers are MP4, MOV, or M4V. ProRes 422 HQ in MOV is another supported option. H.264 audio specifications are stereo AAC, 256 kbps, 44.1 or 48 kHz. The planned output is MP4, H.264 High 4.0, 30 fps, 11 Mbps target, and a silent stereo AAC track at 48 kHz. Including silence is our compatibility choice; Apple's page does not expressly say every silent preview must include audio.

The video uses the accepted preview dimensions, not the native screenshot dimensions. Native portrait footage is proportionally scaled and minimally padded, never stretched.

## Twenty-second edit

Real navigation and scrolling demonstrate the app at normal speed, with brief settled views for readability. The table is the capture brief; `edits/<locale>.json` records the final selection from usable footage. Simple cuts separate the scenes; no slideshow, synthetic scroll, animated screenshot, external photography, phone bezel, or invented interaction is used.

| Time | Real screen and action | Short caption |
| --- | --- | --- |
| 0–5 s | Cooking feed list. Pause on the ten sources, make a short scroll, and settle. | A home for your favorite sources. |
| 5–10 s | Cooking stories. Scroll the actual list/cards enough to reveal another story. | Your daily reading, in one place. |
| 10–15 s | Opened pasta article. Scroll through its real text and photograph, then pause. | Settle into a good read. |
| 15–20 s | Saved Stories. Show the real saved collection and briefly scroll it. | Save a good read for later. |

The last scene also displays “A NewsBlur account is required. Some features require a paid subscription.” Captions and disclosure come directly from the canonical screenshot copy in `../screenshots/copy/<locale>.json`: feeds uses headline 2, stories headline 1, reader headline 3, and saved headline 4. Use a real settled frame at 8 seconds as the poster candidate, then verify that exact frame before selecting it in App Store Connect.

[Apple's preview guidance](https://developer.apple.com/app-store/app-previews/) calls for footage from the app, readable supporting copy, appropriate content rights, and disclosure of login or purchase requirements. This plan uses native NewsBlur captures from the isolated cooking demo: ten fictional sources, twenty original stories, and five licensed food photographs. Full credits and capture instructions are in `clients/ios/MarketingCooking/`. Story content is English demonstration content. It must not be described as a real publisher's article or automatically translated story.

## Files and editing

- `storyboard.json` is the timing, capture-state, and export specification.
- `copy/en.json` contains the editable English captions and disclosure.
- `encode.cjs` reads four supplied video recordings, creates editable ASS captions and a render plan, and only encodes when passed `--execute`.
- `render.cjs` selects the corresponding native-language recording and reviewed cuts in `edits/<locale>.json`. A missing localized edit or recording fails explicitly. It never substitutes English footage for another locale.
- `../screenshots/footage/<device>/scroll.mp4` contains English inputs. Localized recordings use `../screenshots/footage/localized/<locale>/<device>/scroll.mp4`.
- `exports/<locale>/<device>-cooking-preview.mp4` is the output convention.
- `exports/manifest.json` records the final outputs, source hashes, timing, caption provenance and review status. The adjacent `*-edit/` directories preserve exact commands, captions and probe reports.

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

Without `--execute`, this checks input streams and available duration, and writes only the edit plan and ASS subtitle file beside the requested output. It does not run an encoder. Review the selected intervals before adding `--execute`. If the actual footage requires a different rhythm, `--durations 3,5,7,5` changes scene lengths. The total must be 15–30 seconds, retained scenes must be at least two seconds, and the final scene must allow at least four seconds for the disclosure. A zero duration omits a scene and its input. Captions follow the actual edit boundaries. Never stretch or synthesize motion to fill an interval. An explicitly reviewed final Saved frame may be held unchanged for disclosure readability using `--saved-final-frame-hold`; this is recorded as a still hold, never claimed as live motion. Normal frame repetition to convert genuine variable-frame-rate screen recording to 30 fps is expected. Existing output files are not overwritten. Encoding runs one output at a time with bounded decoder/encoder/filter threads. Do not run parallel encodes or overlap recording on the shared Mac.

The encoder converts the source timeline to constant frame rate before trimming the intervals. Simulator recordings can hold a single frame for tens of seconds. Input seeking or resetting timestamps before conversion can drop that held frame and advance a scene early; post-conversion trimming keeps the actual source time and exact scene duration. The source must retain its original timing. Host-wall capture checkpoints alone are insufficient to choose cuts.

To reproduce a reviewed locale, move its existing output to an archive first, then run `node clients/store/artwork/ios/16.0/preview/render.cjs --locale en --device iphone --execute`. Repeat serially for `--device ipad`. Add a locale edit only after inspecting that locale's actual captured video, setting `source_ui_locale` to its language, `source_sha256` to that recording's SHA-256, and `source_intervals_reviewed` to true. The renderer refuses a changed source hash. Offsets from English are not automatically transferable to another capture.

The initial English iPhone edit uses source offsets `31,61,86.5,101.5` with lengths `4,3.5,7,5`, totaling 19.5 seconds. The initial iPad edit uses offsets `0,8.4,12.4,21.4` and lengths `0,4,8.5,4.5`, totaling 17 seconds. The iPad's original recording has only a brief feed sidebar followed by an empty loading view, so that scene is omitted instead of padding it. Source recordings are `../screenshots/footage/iphone/scroll.mp4` and `../screenshots/footage/ipad/scroll.mp4`. The iPhone reader selection includes the actual article scroll around source seconds 88–91. Encoded cuts were checked against the footage using two-frame-per-second contact sheets.

Captions use libass with font fallback for complex scripts. The installed FFmpeg exposes both `ass` and `subtitles` filters. A supported system font is selected by script; visual checking is still required, especially for Arabic, Hebrew, Devanagari, Thai, and CJK. The script rejects untranslated locale fallback: each locale requires its own copy JSON and the caller must supply the corresponding native-language footage. The original English story content can remain visible inside the localized app.

Arabic and Hebrew use libass `Encoding=-1` for paragraph direction and mixed-script ordering, plus `BorderStyle=4` for a single rectangular background across shaped glyph runs. This avoids reversed sentence order around “NewsBlur” and ragged per-glyph boxes. These are [documented libass extensions](https://github.com/libass/libass/wiki/Libass'-ASS-Extensions); the subtitles are burned into the final video, so store playback does not depend on an ASS renderer.

## Localization and review

Produce one iPhone and one iPad preview for each of the 21 supported locales once the capture workflow supplies native UI recordings and reviewed caption files. `copy/<locale>.json` must have exactly `feeds`, `stories`, `reader`, `saved`, and `disclosure`. Record translation review separately; filenames alone do not prove a translated interface.

French, Arabic and German iPhone previews and French, Arabic, German, Hebrew and Spanish iPad previews pass technical checks, full-timeline sampled visual review and normal-speed QuickTime playback. Together with the two English exports, ten exports have passed playback. Arabic and Hebrew include the verified RTL caption correction. French iPad retains a brief transition into Saved Stories and a real bread-article selection near the ending; stepping back from QuickTime’s beyond-end black position confirmed the valid final encoded Saved frame. German and Spanish retain brief native navigation into their settled final Saved scenes. Hebrew iPhone remains held for a corrected capture after delayed screen transitions. Italian’s normalized native refresh, Dutch and Brazilian Portuguese iPad previews are now encoded and pass technical and full-timeline sampled visual review; their normal-speed playback remains pending. The renderer refuses edits whose status starts with `hold_`. Other locale captions are ready while native capture, timing review and encoding continue.

The script checks technical output properties and writes a probe report. It cannot prove useful motion, correct language, missing glyphs, readable captions, clean scene cuts, settled sync state, lack of personal data, or a good poster frame. Review the entire actual video before upload. Verify processing and App Review submission independently; a local valid video is not a submitted preview.

Indonesian iPad uses the approved final-frame hold: the raw recording ends shortly after Saved loads, so its exact final decoded frame (384) is held for the four-second disclosure. `proof/id/ipad-final-source.png` records those actual source pixels. The preceding sixteen seconds remain real native footage. `edits/id.json` explicitly enables and reviews this exception; `render.cjs` refuses an unreviewed hold.
