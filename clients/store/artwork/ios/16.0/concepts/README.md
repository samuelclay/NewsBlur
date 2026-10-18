# NewsBlur iOS store artwork: 10 concepts

Open http://127.0.0.1:8767/ to compare the ten current directions. Click a concept to preview header, search, and custom product page layouts. Favorites are stored only in this browser and can be copied back into chat.

- Round 03 is the current direction: real screenshots, stronger typography, restrained color panels, subtle framing and gold accents. Round 01 was rejected as too AI-looking; round 02 was too plain and sparse.
- Current layouts are HTML/CSS compositions using the exact existing NewsBlur icon. No generated artwork is used in the current gallery.
- All current concepts reference historical public screenshots, not fresh v16 runtime captures. These are layout studies, not final store-resolution exports.
- Header and search compositions reflow separately for their respective aspect ratios. Final exports must still be checked against Apple template safe areas.
- English concepts first; localize chosen text and UI across all 21 app languages.
- No store mutations or commits performed for this concept round.

## Production asset plan after selection

### Product page header

3840 × 1646, opaque PNG. Recompose selected art to Apple template safe areas.

### Search results

3840 × 2560, opaque PNG. Pair selected artwork with real v16 feed and reading captures.

### Universal alternative

5244 × 2950, opaque PNG. Optional shared header/search master; validate both crops.

### Custom product pages

Feature-specific header, search art, screenshot sequence and promotional text. Prepare three pages: Read your way; Find your focus; Save and explore. Actual deep links must be verified before use.

### Screenshots

Current supported iPhone and iPad display sizes. Fresh v16 captures, localized headlines, real interface content.

### Preview video

Storyboard after visual direction selection. Real app footage demonstrating follow, read, train and save.

### Subscription promotion

1024 × 1024, subject to current product form requirements. Coordinated Premium, Archive and Pro art; leave prices and terms in store metadata.

### Featuring artwork

Use Apple-requested template if nominated. Adapt the chosen art when the actual request specifies deliverables.

### In-app event artwork

Conditional on a genuine qualifying event. Do not fabricate an event to fill an asset slot.

## Sources

- https://developer.apple.com/app-store/asset-best-practices/
- https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications
- https://developer.apple.com/app-store/custom-product-pages/

## Prompts and provenance

index.html contains the current compositions and copy. contact-sheet-refined.png shows round 03. round-1.html and round-2.html preserve earlier rejected approaches. manifest.json applies only to round 01 and preserves its image generation provenance. references/ contains public App Store screenshots and the existing NewsBlur app icon used for layout studies.
