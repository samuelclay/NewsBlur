# iPhone Duo screenshots for the iOS 16.0.1 draft

The original four-panel landscape set adapted the approved 16.0 Sage artwork to the unfolded iPhone Duo. The current App Store Connect draft uses the four-state v2 revision documented below, with closed-mode panel 1 and full-screen panel 4; original panels 2 and 3 are preserved. It retains the original NewsBlur icon, palette, CoreText typography, headlines and labels. The text occupies the left column; the real native screen occupies the official device frame at right. Arabic and Hebrew headlines and labels are right aligned within the text column. Source titles and cooking articles remain in English.

## Inputs and rendering

- Approved copy: `../../16.0/screenshots/copy/<language>.json`, reused without changes.
- Brand icon: `../../16.0/selected/assets/icon.png`.
- Native screenshots: `captures/<language>/duo-{stories,feeds,reader,saved}.png`. Each must be an unaltered 2853 × 2007 capture of the actual app in its corresponding language. Capture orchestration and source provenance are recorded separately.
- Frame: `assets/iphone-duo-inner-landscape.png`, Apple's original `iPhone Duo - Night Sky - Inner Open Landscape.png`.
- Renderer: `native-render.swift`, adapted from the approved `../../16.0/screenshots/native-render.swift`; the original renderer and approved exports remain unchanged.

Render a complete capture set:

```sh
ruby clients/store/artwork/ios/16.0.1/duo/export-native.rb --language en
```

Use `--all` only when all languages' captures are complete. The exporter derives language coverage from `localization/languages.json`, compiles the renderer once per invocation, and refuses to overwrite existing exports. Output names include version, canonical language, device, display size and panel number.

The exporter validates PNG dimensions, opacity, source hashes, and the embedded native screen against its source capture with `../../16.0/screenshots/verify-native-pixels.rb`. It creates `render-checks.json`, `validation.json`, and a 2 × 2 `contact.png` in each language's export directory. These technical checks do not establish visual approval or persistence in App Store Connect; those checks must be recorded separately before upload is called complete.

For design-only previews, compile `native-render.swift` and pass `--capture /absolute/native.png` alongside `--language`, `--size 2853x2007`, `--panel 1` and `--output /tmp/preview.png`. The override is recorded as the capture path. This does not create a canonical export or establish localized capture coverage.

## Official frame provenance

Apple Design Resources: https://developer.apple.com/design/resources/

Download: https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-Duo.dmg

Original relative path inside the mounted disk: `PNG/iPhone Duo - Night Sky - Inner Open Landscape.png`. The accompanying Apple Design Resources license is retained in `assets/Apple-Design-Resources-License.rtf`.

The original frame is 3093 × 2247. Its transparent screen opening begins at `(120, 120)` and is 2853 × 2007. Center-axis alpha inspection confirms horizontal clear pixels 120–2972 and vertical clear pixels 120–2126. The native screenshot is uniformly scaled into that opening and clipped only to its rounded hardware corners; no interface pixels are redrawn, stretched independently, or rearranged. The frame PNG itself is unchanged.

Media under this directory belongs to the private repository assets bucket, not git. Preserve the manifests and source scripts in git; use the repository assets workflow for images.

## Renderer revision evidence

English and Spanish were exported and verified in the store before the narrow-column word-fitting refinement. Their exact original renderer, SHA-256 `21cbb6bcf06b93c0c858dfa5f23796741e759cec805bea3d8b55bb83e2f042a5`, is preserved in `renderer-revisions/21cbb6bcf06b93c0c858dfa5f23796741e759cec805bea3d8b55bb83e2f042a5.swift`. Their approved PNG files remain unchanged. Subsequent languages use the current renderer, which keeps whole words while balancing narrow headline lines and reduces type size as necessary; Chinese, Japanese and Thai retain CoreText's native line-breaking rules. A rejected initial French export is not part of the canonical export tree.

## Capture and draft scope

This task prepares screenshots and the next-version draft only. It does not archive, upload or submit an iOS release. The App Store Connect destination is [iOS 16.0.1](https://appstoreconnect.apple.com/apps/463981119/distribution/ios/version/inflight), with an explicit iPhone Duo placement for each supported locale.

The capture binary is Debug 16.0.1 (350), built from `bf81b82315d2d35384e79fcfebc0c0664104dc8d` using public Xcode 27.1 (27A9269), the `NewsBlur` scheme and the explicit `SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG` capture override. It uses the existing isolated `clients/ios/MarketingCooking` dataset, local licensed food photos and the Alex demo identity. No production reading account is modified.

`capture.rb` serializes launch/capture work on existing Duo `D570C816-B762-48E2-AC94-C592153A896D`, explicitly selecting inner display 3. It saves untouched native PNGs and per-locale `ready.json` provenance. `capture-ocr.swift` checks content readiness; photo and visual review provide separate checks. The capture-only build and simulator data backups stay outside the repository. Both standard and shared app data are restored after capture.

`independent-review.json` records visual review tied to exact export hashes. `store-readback.txt` records the locale, filenames and four-image count after reloading App Store Connect and reselecting that locale. Run `verify-draft.rb` only after all 21 sets have passed review and persisted placement verification.

`renderer-revisions/` also retains the exact export-script revisions referenced by those first sets' source hashes. They differ only in command-line option validation or an unused copy-root variable; the original files' hashes and all eight uploaded PNG hashes were rechecked after preservation.

## Requested four-state revision (v2)

The requested replacement sequence is: closed Duo showing only story titles; the original sources screenshot; the original titles-and-article screenshot; and an open Duo showing the article full screen. Panels 2 and 3 are reused byte for byte. Original captures, exports, reviews and store readbacks remain preserved.

`capture-revision.rb closed` captures the actual outer display in its Closed pose at 1398 × 2034. `capture-revision.rb fullscreen` captures the actual Open landscape inner display at 2853 × 2007 with the account's full-screen reader preference enabled. The Debug-only `-newsblur-marketing-fullscreen` fixture flag waits for the real article paint gate and invokes the normal story-selection sidebar dismissal once. Device Hub must supply the real pose before each serial batch. Each scene has its own native PNG and hash metadata under `revisions/v2/captures/<language>/`.

The closed frame is Apple's unchanged `PNG/iPhone Duo - Night Sky - Outer Closed Portrait.png`, from the same official download cited above. The user approved the license acceptance on October 26, 2026. Its measured screen opening is `(88, 80, 1398, 2034)` in a 1574 × 2194 PNG. The renderer follows the frame's connected transparent interior, preserving its asymmetric corners and camera cutout; `assets/iphone-duo-outer-closed-portrait.json` records those measurements.

After both capture batches are complete, render the revision:

```sh
ruby clients/store/artwork/ios/16.0.1/duo/export-native.rb --all --revision v2 --revision-inputs clients/store/artwork/ios/16.0.1/duo/revisions/v2/inputs.json
```

Revision exports use unique `-v2` filenames for panels 1 and 4. Their manifests reference the unchanged original panel 2 and 3 files. Independent visual review and App Store Connect readback are required separately. `verify-revision.rb` writes `revisions/v2/draft-verification.json` only after all 21 localized sets pass capture, pixel, review, original-preservation and ordered-placement checks. The existence of capture or render files alone does not establish upload completion.

Revision v2 was saved and verified in all 21 App Store Connect localizations on October 26, 2026. `revisions/v2/draft-verification.json` records all 84 ordered placements, including 42 new exports and 42 unchanged originals. All sets passed independent visual review and native-pixel comparison. The 106 new media files are stored in the repository asset bucket and referenced by `clients/store/artwork.manifest.json`. The original simulator app, standard/shared data, and shutdown state were restored and hash-verified; see `revisions/v2/simulator-restoration.json`. This screenshot-only update does not submit the iOS draft for review.
