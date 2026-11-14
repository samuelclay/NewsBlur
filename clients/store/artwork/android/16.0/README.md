# NewsBlur Google Play 16.0 artwork

The approved direction adapts the iOS Sage panels and cooking demonstration for Android. All app images must be fresh Android captures. There are no Apple devices or iOS screen images in these assets.

## Editable sources

- `native-render.swift`: offline CoreGraphics/CoreText layout. Soft cream, Sage, restrained typography and the actual Android app are the visual system.
- `copy/<language>.json`: four localized screenshot headlines and labels, plus feature headline/subheadline, for all 21 supported languages. These platform-neutral strings reuse the approved, reviewed iOS artwork copy. The feature text comes from the approved selected creative; screenshot text comes from Sage panels.
- `preview/copy/<language>.json`: four localized video captions and the account/paid-feature disclosure. These are platform-neutral captions from the approved iOS preview. They are text sources only; Android footage, encoding and YouTube upload remain separate work.
- `assets/icon-source.png`: the 1024-pixel Android `app_icon_ember_orange.png` source, copied without modification from `clients/android/NewsBlur/app/src/main/res/drawable-nodpi/`. The Play export is 512 × 512 RGBA with fully opaque pixels, without added rounding or shadows.
- `captures/<language>/<device>-<view>.png`: required fresh native captures. Devices are `phone`, `tablet7`, `tablet10`; views are `stories`, `feeds`, `reader`, `saved`. English also uses its own `captures/en/` directory. There is no language fallback.
- `export-native.rb`: complete-group export, immutable-source checks, screenshot pixel comparison and inventory generation.
- `verify-native-pixels.rb`: shared comparison logic adapted from the iOS renderer. It compares the interior of each actual screen with its source capture after scaling. No app text or imagery is recreated.

## Placements

| Play image type | Count per language | Output |
|---|---:|---|
| `icon` | 1 | 512 × 512 RGBA PNG, fully opaque pixels |
| `featureGraphic` | 1 | 1024 × 500 opaque PNG |
| `phoneScreenshots` | 4 | 1080 × 1920 opaque PNG |
| `sevenInchScreenshots` | 4 | Full-screen source dimensions, opaque PNG |
| `tenInchScreenshots` | 4 | Full-screen source dimensions, opaque PNG |

The total is 294 images across 21 languages. The unchanged brand icon is intentionally identical across locales. Four native views are independently captured for each form factor; a phone image is never passed off as a tablet image.

Phone captions occupy the top 13% of the composition. The complete app screen is fitted without cropping or stretching onto a Sage field, with a fine border, without a device mockup. The feature graphic has the same localized copy and two real Android app views. Tablet screenshots contain only the full-screen app, without added text, frames, padding or cropping. For Google's recommended aspect ratio, capture tablets at native 1920 × 1080 or 1080 × 1920 when practical; the renderer preserves other valid native dimensions instead of distorting them.

[Google's preview asset guidance](https://support.google.com/googleplay/android-developer/answer/9866151) was checked on October 17, 2026. Basic screenshot dimensions are 320–3840 pixels, with the long side at most twice the short side. Four high-resolution screenshots and 16:9 or 9:16 proportions are recommended. Google discourages device imagery, recommends keeping phone taglines below 20% of the image, and recommends actual full-screen tablet images without external text. The feature graphic is 1024 × 500. Those recommendations motivated the Android adaptation.

## Rendering and verification

```sh
ruby clients/store/artwork/android/16.0/export-native.rb --language en --placement icon
ruby clients/store/artwork/android/16.0/export-native.rb --language en --placement featureGraphic
ruby clients/store/artwork/android/16.0/export-native.rb --language en --placement phoneScreenshots
ruby clients/store/artwork/android/16.0/export-native.rb --language en --placement sevenInchScreenshots
ruby clients/store/artwork/android/16.0/export-native.rb --language en --placement tenInchScreenshots
```

Swift is compiled locally on macOS. No browser, simulator or network is used by the renderer. Captures must already exist. Missing captures, invalid copy, text that will not fit, unsupported dimensions, incorrect alpha-channel format, changed sources or mismatched app pixels stop export. Existing export groups are preserved; do not casually overwrite reviewed assets.

Each complete group writes four panels (or one icon/feature image) and `validation.json` under `exports/<language>/<imageType>/`. `exports/manifest.json` aggregates the uploader schema:

```json
{
  "packageName": "com.newsblur",
  "version": "16.0",
  "assets": [
    {
      "language": "en",
      "locale": "en-US",
      "imageType": "phoneScreenshots",
      "position": 1,
      "path": "en/phoneScreenshots/panel-01.png",
      "sha256": "sha256 of actual exported file",
      "visual_review": "required",
      "store_upload": "unverified"
    }
  ],
  "videos": []
}
```

Paths are relative to `exports/manifest.json`. Each record also contains source hashes, dimensions, measured text sizes and app-pixel evidence. Verify the final complete image visually in every language before changing its review status in the corresponding `validation.json` and aggregate manifest. Technical validation alone does not establish visual approval. Store upload and persistent readback are recorded separately. A rendered file is not an uploaded, reviewed or publicly available store asset.

## Capture and video sources

The isolated `com.newsblur.storecapture` build seeds offline cooking fixtures and presents the app's native activities. It has no Internet permission and does not alter accounts in the installed production or alpha apps. The S22 supplies phone captures; the Samsung tablet supplies independent portrait seven-inch and landscape ten-inch layouts. `capture-native.rb`, `capture-resume.rb`, and `capture-tablet.rb` retain PNGs, UI hierarchies, capture timestamps and source hashes. Device restoration evidence lives in `proof/`.

`preview/encode.cjs` produces a 28-second, 1920 × 1080 promotional video for each language, using four phone scenes followed by four tablet scenes. Native motion stays at its recorded speed. Android can omit unchanged frames at the end of a recording, so a documented final-frame hold completes a scene when needed. No app controls, animation or story content are generated by the renderer. Each editable render plan records source hashes and hold durations. Localized SRT captions accompany the video.

`preview/upload-metadata.json` is the authoritative YouTube upload inventory. Only entries marked `published_unlisted` have a verified hosted video. All other entries remain pending; no English video is silently substituted. Full decode, sampled scene review and hosted playback are recorded separately. On October 17, YouTube accepted ten promos before reporting its daily upload limit. The remaining eleven require the limit to reset or the channel owner to complete the offered verification.

## Store upload and readback

On October 17 at 18:32 UTC, edit `03809724643036911628` was validated and committed with `ERROR_IF_IN_REVIEW`. Fresh edit `06451369022117040990` verified all 294 images across 21 locales and all ten hosted promo URLs, including exact image hashes and ordering. Production 16.0/292, translated listing text, and unrelated assets remained unchanged. Console showed 115 listing changes under **Changes in review**, with automated quick checks running and managed publishing off. This confirms submission, not public availability. Eleven additional promos still await YouTube's daily upload reset. See `proof/play-assets-postcommit-verification.json` and `proof/play-publishing-submitted.txt`.

Before a large upload, inspect the selected service account's existing Play permissions and validate the untouched edit. Successful image uploads do not prove permission to commit: the configured billing account accepted all 294 images on October 17 but returned HTTP 403 for both validation and commit because it lacked `Manage store presence`. The separate reporting account has read-only access. Confirm any access expansion with the user, or use the authenticated Console upload workflow. Do not silently grant production-release or administrator access for a listing-only refresh.

The user subsequently approved `Manage store presence` for the billing service account on `com.newsblur` only. Google automatically included its `Manage policy declarations` dependency. No administrator or release permission was granted. Validation and commit then succeeded.

Run the complete audit before uploading:

```sh
ruby clients/store/artwork/android/16.0/audit-assets.rb --output clients/store/artwork/android/16.0/proof/assets-final-audit.json
```

`clients/store/google_play_assets.py` runs inside `newsblur_web`. It requires all 294 approved images, validates exact file hashes and locale mappings, and stages them in an explicitly supplied Play edit. Its checkpoint makes interrupted uploads resumable. Freeze `exports/manifest-staging.json` with all reviewed images and the ten verified localized YouTube URLs before staging. Additional videos belong in a subsequent edit after their uploads and playback checks finish, so they do not change the active checkpoint. Listing text, release tracks and unrelated assets are preserved.

After staging, validate and commit the edit, then open a fresh readback edit and verify image count, order, hashes and video URLs. Finally inspect Play Console's publishing overview. `verified_in_edit` means staged, and a successful edit commit is not by itself evidence that Google's review has finished. Proof files record these distinct stages.

Use `changesInReviewBehavior=ERROR_IF_IN_REVIEW` for the commit so an unrelated review cannot be canceled by this artwork refresh. [Google's commit reference](https://developers.google.com/android-publisher/api-ref/rest/v3/edits/commit) documents this parameter; older installed API discovery documents may omit it. Recheck the Console state if Google reports an existing review.
