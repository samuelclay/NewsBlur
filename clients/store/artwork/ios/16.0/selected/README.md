# NewsBlur iOS 16.0 artwork

Approved October 16, 2026: concept 05 copy, concept 08 layout, and three app views inspired by concept 07. Two iPhone 18 Pro Max bezels and one 13-inch iPad Pro (M5), using official Apple artwork.

## Editable source

- `index.html`: layout, colors, typography, device placement and CSS screenshot crops. No generated illustration is used.
- `copy/<language>.json`: five editable marketing strings in each of the 21 supported app languages. Translations were generated in two parallel batches and independently cross-reviewed.
- `assets/`: original unmodified Apple bezel PNGs, NewsBlur icon, source screenshots, and accepted Apple Design Resources license.
- `exports/<language>-header.png`: 21 opaque PNG headers at 3840 × 1646 pixels.
- `exports/<language>-search.jpg`: 21 opaque JPEG search images at 3840 × 2560 pixels.
- `exports/manifest.json`: the 42 canonical assets, with dimensions, actual formats and SHA-256 checksums. Older JPEG headers and trial/universal exports are excluded.
- `submission.json`: verified App Store Connect submission state, separate from preparation and upload.

Serve from the repository root:

```sh
ruby -run -e httpd clients/store/artwork/ios/16.0 -p 8768 -b 127.0.0.1
```

Preview `http://127.0.0.1:8768/selected/`. Add `?placement=header&lang=ja` for a localized header. Add `export=1` to hide preview controls. Render the header at exactly 3840 × 1646 pixels, or search at 3840 × 2560 pixels. Wait for `html[data-ready="true"]` and loaded images before capture.

App Store Connect rejected the JPEG header exports during this upload. The accepted header files are real PNGs, and the accepted search files are real JPEGs. A filename extension does not change the encoded format: browser captures can contain JPEG bytes even when named `.png`. Export or convert to the required format, flatten transparency, and validate before upload.

From the repository root:

```sh
ruby clients/store/artwork/ios/16.0/selected/validate.rb
```

The validator requires exactly the 21 supported copy locales and their 42 canonical export filenames. It verifies file signatures, decoded formats, dimensions and absence of an alpha channel, then regenerates `exports/manifest.json`. It ignores historical/trial exports and does not rename or modify images.

`review.html` shows the localized search exports together. Arabic and Hebrew use RTL text alignment without mirroring the app screenshots or Apple artwork. The brand remains NewsBlur.

## Provenance

Official Apple bezels: https://developer.apple.com/design/resources/#product-bezels

- iPhone: `https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-18.dmg`, iPhone18ProMax Black portrait.
- iPad: `https://devimages-cdn.apple.com/design/resources/download/Bezel-iPad-Pro-(M5).dmg`, 13-inch iPadProM5 SpaceBlack portrait.
- License acceptance explicitly authorized by Sam in this conversation.
- Feed screenshot: `media/img/iphone/iPhone 14/iPhone_XS/1.jpg`.
- Reader screenshot: `media/img/iphone/iPhone 14/iPhone_XS/6.jpg`.
- iPad screenshot: `media/img/iphone/iPad Pro 12.9/Simulator Screenshot - iPad Pro (12.9-inch) (6th generation) - 2023-10-06 at 08.12.34.png`.

The app screenshots are historical English screenshots approved as part of this composition. They are not fresh v16 captures and their app UI/story content is not translated. The surrounding marketing headline, subheadline and labels are localized in all 21 languages. Replace the source files and adjust the CSS screen crop to update them later.

Placement requirements: https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications

All 42 approved creative files are uploaded and attached across all 21 locales of the custom product page **Daily reading • 16.0**. The page was submitted on October 16, 2026 at 12:42 PM Pacific and is **Waiting for Review**. [App Store Connect submission](https://appstoreconnect.apple.com/apps/463981119/distribution/reviewsubmissions/details/095b78c7-53b0-4c44-816b-b6962f83cf94). Submission evidence is saved in `proof/submitted-review.jpg` and `proof/submitted-review.txt`; identifiers and placement state are recorded in `submission.json`.

The separate iOS 16.0 app submission was removed from review to add the main-page assets. The user selected 01 Sage panels for fresh cooking-demo screenshots and authorized a short App Preview video. Main-page preparation and resubmission are tracked in ../resubmission.json. The app version and this custom product page have separate review submissions; Waiting for Review does not mean approved or publicly available.
