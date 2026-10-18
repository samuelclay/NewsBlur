# Primary English asset placement failure

Observed on October 16, 2026 for NewsBlur, app ID `463981119`, iOS version `16.0`, build `343`. The version is **Developer Rejected** after the authorized withdrawal from review. No replacement submission has been sent.

## Diagnosed screenshot cause

A fresh App Store Connect tab reproduced the English screenshot failure while recording the browser's actual responses. Each new medium-iPhone placement returned HTTP 409, `STATE_ERROR.ASSETS_PER_PLACEMENT_LIMIT_EXCEEDED`: the placement group already contains its limit of ten screenshots.

The page's placement-list response returned only **50 of 81** records and supplied a next-page cursor. All 50 returned records were legacy screenshots: 8 iPad 13-inch, 8 iPad 12.9-inch second-generation, 5 iPad 9.7-inch, and 29 older Home-button iPhone screenshots. No modern medium-iPhone placements appeared in that first page. The UI's zero count therefore cannot be treated as evidence that earlier uploads were not saved. Repeated attempts created placements that the truncated readback did not display.

Recovery is complete for screenshots. Removed obsolete draft placements through Media Manager while retaining their Asset Library files. The revealed medium-iPhone group contained two copies of `panel-1.png` through `panel-4.png` and two uniquely named retry files, explaining the ten-image limit. Replaced this group and the old large-iPhone and iPad sets with the four approved, uniquely named panels per size. Removed the remaining older device overrides so they inherit the new sets.

After a full reload, English showed exactly four expected filenames at each of 1206 × 2622, 1320 × 2868 and 2064 × 2752. Recovery evidence is committed in `814425c3e`. Header/search behavior still needs a separate recheck; screenshot recovery does not establish that those placements are fixed.

- [Recovered English iPhone sets](en-iphone-screenshots-persisted.jpg)
- [Recovered English iPad set](en-ipad-screenshots-persisted.jpg)

- [Placement-limit error responses](en-placement-limit-errors.json)
- [Observed first-page counts](en-placement-pagination.json)

The historical observations below describe what the UI displayed, not a reliable inventory of all stored placements.

## Reproduction

1. Open the main 16.0 version page in App Store Connect.
2. Explicitly select French, then English (U.S.), the primary localization.
3. Under Header and Search Results → Header → Browse Assets, select `en-header.png` and Save.
4. App Store Connect reports **“An error has occurred. Try again later.”** The header remains empty.

The failure also occurred for the English search asset, including a newly uploaded asset in Prepare for Submission. Explicitly switching away from and back to English did not resolve it.

## Screenshot upload comparison

Four reviewed, opaque PNGs at 1206 × 2622 were uploaded using the native macOS file picker. Files used unique locale/size/panel names.

- French: all four `newsblur-16.0-fr-1206x2622-01.png` through `-04.png` remained attached after a full reload and explicitly reselecting French. The page showed **4 of 10 App Screenshots** and the four expected filenames.
- English: panels 1 and 2 temporarily appeared; panels 3 and 4 reported **“An error occurred during upload.”** After a full reload, English showed **0 of 10 App Screenshots**.
- An earlier English upload and subsequent Asset Library assignment both temporarily showed four screenshots, then returned to zero after reloading. Files remained in Asset Library.

The browser extension and native uploader both exhibited the misleading English readback. The browser connection was separately recovered by opening and closing its existing ChatGPT sidebar, but that did not resolve the truncated placement list.

An independent `sips` inspection found the English and successful French medium screenshots both use opaque RGB PNG, 1206 × 2622, and the same sRGB IEC61966-2.1 profile. Their header PNGs are both opaque RGB, 3840 × 1646, and use the same embedded Google/Skia profile. These checks do not explain the English-only failure.

All 20 non-English header/search pairs passed readback after a full page reload and explicit locale selection. Reloading resets the locale to English (U.S.), so that reset was accounted for during verification.

## Evidence

- [English native upload error](en-native-upload-error.jpg)
- [French screenshots persisted](fr-main-screenshots-persisted.jpg)
- [Header save error](main-artwork-save-error.jpg)
- [Non-English creative readback](non-english-creative-readback.json)
- [Current release checkpoint](../resubmission.json)

Apple's [asset management instructions](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-store-assets) list Developer Rejected as an editable upload state. The generic UI error initially concealed the placement-limit and pagination evidence documented above. No support message has been sent.
