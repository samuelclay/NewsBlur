# NewsBlur App Store screenshot concepts

The selected **01 Sage panels** direction has four portrait marketing panels in all 21 supported languages: daily reading, favorite sources, reading view, and saved stories. The other seven directions remain in the gallery as their original three-panel studies. Screenshot preparation and export do not establish store submission.

## Canonical offline export

The accepted offline renderer produces new Sage sets without a browser or UI automation. Run `ruby clients/store/artwork/ios/16.0/screenshots/export-native.rb --language ar --size 2064x2752`. It compiles `native-render.swift`, reads the canonical copy and unchanged native capture and bezel PNGs, renders all four panels with CoreGraphics/CoreText, and validates PNG signatures, exact dimensions, opacity, source hashes and native-content pixels before installing the set. It refuses to overwrite any existing panel set, preserving approved browser exports already uploaded. Missing localized captures fail explicitly.

Review every panel in `exports/<language>/<size>/contact.png` and the full-resolution images for correct native interface language/state and readable copy. Only then use `stage-uploads.rb --language ar --size 2064x2752 --reviewed`. The generated render evidence records all source hashes and the exact native screen rectangle. Validation and staging remain separate from store attachment and fresh-read persistence checks.

After staging a reviewed batch, run `ruby clients/store/artwork/ios/16.0/screenshots/refresh-export-queue.rb`. It checks all staged screenshot hashes against their validation records and reconciles the complete/pending sets for all 21 locales and three sizes. Optional `--capture-status STATUS` and `--capture-checkpoint SHA` record the capture coordinator's current checkpoint. It does not infer capture readiness from uncommitted file presence or report store placement from local staging.

English iPad, French iPhone and Arabic iPhone comparisons were reviewed and accepted against the browser exports. The geometry and line breaks match closely; CoreText font fitting and antialiasing are not pixel-identical to Chromium (the French first headline fits 0.5 pixel smaller). The output uses lossless PNG encoding. The original native capture is scaled into the official device opening without edited controls, reconstructed UI or content cropping. The HTML gallery remains an editable design reference, and the CUA route below remains available for browser comparison.

## Preview

Serve the parent release directory with the existing local server:

```sh
ruby -run -e httpd clients/store/artwork/ios/16.0 -p 8768 -b 127.0.0.1
```

Open `http://127.0.0.1:8768/screenshots/`.

- `?device=ipad`: all eight iPad directions.
- `?mode=contact`: condensed comparison view.
- `?concept=01&device=iphone&lang=fr`: the selected four-panel sequence in French.
- `?concept=08&device=iphone`: one of the original English concept studies.
- `?concept=01&device=iphone&lang=ja&panel=2&export=1&size=1320x2868`: one localized large iPhone export.
- `?concept=01&device=iphone&lang=ja&panel=2&export=1&size=1206x2622`: the medium iPhone export.
- `?concept=01&device=ipad&lang=ar&panel=4&export=1&size=2064x2752`: the Arabic saved-stories iPad export.

Set the viewport to the exact requested export size and device scale to 1. Supported canvases are 1320 × 2868 and 1206 × 2622 for iPhone, and 2064 × 2752 for portrait iPad. The medium iPhone export scales the same native large iPhone capture inside its device frame. Check the destination screenshot slot before upload. The page has no export margins. Wait for `html[data-ready="true"][data-missing-images="0"][data-font-fit="true"]`, then capture the rendered panel. Readiness waits for image decoding and fonts, fits localized headlines above the device and labels within their allotted width, and rejects missing images, incorrect native capture dimensions, text overflow, or an incorrect export viewport/scale. Check the encoded image format rather than trusting a filename extension.

Arabic and Hebrew headlines and labels run right to left. The composition and screenshots are not mirrored. The actual native app captures must already show the selected interface language. Non-English captures are loaded only from `captures/localized/<language>/<device>-<view>.png`; there is no English fallback. English deliberately uses the approved root `captures/` files.

The supported CUA browser screenshot API currently returns JPEG bytes. Save those bytes as `/tmp/newsblur-store-screenshot-renders/<language>/<size>/panel-<1..4>.jpg`, then run `ruby clients/store/artwork/ios/16.0/screenshots/finalize-exports.rb --language en`. This converts the decoded screenshot to a genuine opaque PNG without resizing, checks its signature and dimensions, and records SHA-256 checksums beside the exports. It does not restore detail lost during the browser's JPEG encoding. Use `--size 1206x2622` for one size, or `--validate-only` to check existing PNGs. Each result still requires visual review against the native capture. The script does not drive a browser or upload files.

New render evidence includes the native screen's exact DOM rectangle. `finalize-exports.rb` uses `verify-native-pixels.rb` and FFmpeg to compare the exported screen's central 80% with the matching native PNG, rejecting missing or incorrect painted content. It compares mean RGB error and sixteen smaller tiles after downsampling, allowing ordinary browser scaling/JPEG differences. Source hashes must still match the recorded render. This gate catches an observed iPad export that showed a mostly blank screen despite a complete native PNG and successful image decoding. Legacy exports without rectangle evidence explicitly report the pixel check as unavailable. Pixel agreement proves the browser reproduced the capture; a correct native state and readable marketing text still require visual review.

`export-cua.mjs` provides the repeatable capture loop for the approved CUA REPL. Import it there and call `exportScreenshots({tab, viewport, language: 'fr', sizes: ['1320x2868', '1206x2622']})` using an already selected dedicated rendering tab and the documented browser viewport capability. It uses only those CUA handles, checks rendered copy and readiness, rejects captures changed during rendering, records source/checksum evidence, and resets the temporary viewport. Omit `sizes` for all three formats. Do not run this helper with an external browser driver. Its default local server URL is the one above; the server must already be running.

For slow browser sessions, add `panels: [1]` and export one panel per CUA call. Evidence is saved after each successful panel. Resuming retains only records whose renderer, copy, native image, and raw screenshot hashes still match. The finalizer requires all four evidence records before producing a complete validated set. Partial work must not be staged or uploaded.

After visually checking all four exact PNGs, run `ruby clients/store/artwork/ios/16.0/screenshots/stage-uploads.rb --language fr --size 1206x2622 --reviewed`. It verifies the validation checksums and stages uniquely named files such as `newsblur-16.0-fr-1206x2622-01.png` in `/tmp/newsblur-ios16-ready-uploads/`, merging their entries into that directory's existing manifest without removing videos or creative artwork. Changed images reset their placement to unverified. Staging files or seeing them in the store's asset library does not establish persisted attachment to a locale.

## Editable sources

- `index.html`: composition CSS, the eight concept descriptions, capture selection, text fitting, and gallery/export behavior. The selected concept loads canonical locale copy; other studies retain their English copy in the `concepts` array.
- `copy/<language>.json`: four headlines, four labels, and the account/paid-subscription video disclosure. The first two headlines exactly preserve the previously approved creative-artwork copy. All 21 languages have been translated and independently reviewed.
- `manifest.json`: generated local inventory, SHA-256 hashes, exact frame geometry, native capture states, and 252 planned selected-concept exports (21 languages × four panels × three sizes). Missing captures and exports are explicitly pending. File presence does not establish capture approval or submission.
- `refresh-manifest.cjs`: lightweight inventory generator; run `node clients/store/artwork/ios/16.0/screenshots/refresh-manifest.cjs` after replacing captures or changing the gallery. It does not launch a browser, simulator, or build.
- `captures/iphone-feeds.png`, `iphone-stories.png`, `iphone-reader.png`, `iphone-saved.png`: real raw iPhone captures, expected dimensions 1320 × 2868.
- `captures/ipad-feeds.png`, `ipad-stories.png`, `ipad-reader.png`, `ipad-saved.png`: real raw portrait iPad captures, expected dimensions 2064 × 2752.
- `captures/localized/<language>/`: equivalent native localized captures for each non-English locale, with the same device dimensions and filenames. Capture generation can be incomplete while the gallery is being prepared; the renderer blocks those missing locales.
- `../selected/assets/iphone-18-pro-max.png`: unmodified official Apple iPhone artwork, 1470 × 3000.
- `../selected/assets/ipad-pro-m5.png`: unmodified official Apple iPad artwork, 2300 × 3000.
- `../selected/assets/icon.png`: the real NewsBlur icon.

Raw captures fill the exact screen opening, with no cropping or simulated interface. iPhone screen opening: 1320 × 2868 at x=75, y=66. iPad screen opening: 2064 × 2752 at x=118, y=124. The official frame is layered above the raw image. CSS contains no added device shadows, perspective transforms, or filters. Direction 07 adds one clearly separate crop of the same actual screenshot; it does not reconstruct interface elements. Its inset sits beside the complete device with a 4% canvas-width gap and a thin connecting rule, never covering the device or its screen. The inset renders the screenshot at 300% of its own width, about 1.5 times the scale shown inside the complete device. iPhone offsets select real feed rows, saved-story text, or article text. Review the iPad crop against its future captures before treating that variant as complete.

Direction 05 changes only the marketing background to deep green. It does not recolor light-mode screenshots or imply that those captures demonstrate dark mode. Replace capture sources with verified dark-mode captures if that direction is selected for a dark-theme story later.

## Capture and review requirements

The user selected curated demo feeds. The captures use an isolated cooking demo account rendered by the current native NewsBlur app: ten fictional sources, twenty original cooking stories, and five licensed Unsplash photographs. The sources and stories are demonstration content, not real publishers or published articles. The photographs appear inside the actual captured app interface. The interface itself is rendered by NewsBlur, not reconstructed for the artwork.

Keep the demo content isolated from the user's account. Do not alter captured controls to imply unsupported features, or place the cooking photographs outside the captured app screen. Capture provenance, photo licensing details, and runtime verification belong alongside the files when the capture coordinator supplies them.

The demo dataset and native capture instructions are in `clients/ios/MarketingCooking/README.md`. Exact photo pages, downloaded renditions, photographers, and license URLs are recorded in `clients/ios/MarketingCooking/photo-sources.json`. The manifest records hashes of those sources and of `NewsBlurUITestHarness.swift`. Those hashes describe current source files, not proof of which revision an earlier capture used. The capture operator must confirm the installed build and dataset revision, let transient sync indicators settle, and record visual approval separately.

Inspect all four selected panels at all three sizes in all 21 languages for headline wrapping, readability, intact bezels, screen fit, and correct native interface language. Automated readiness checks do not replace visual review. Demo story content stays in its original language unless a separate localized demo dataset is prepared; NewsBlur does not automatically translate stories.

This gallery references the approved artwork assets without modifying `../selected/`. Apple's accepted design license and the original device-artwork provenance remain recorded there.
