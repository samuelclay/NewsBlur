# Primary English asset placement failure

Observed on October 16, 2026 for NewsBlur, app ID `463981119`, iOS version `16.0`, build `343`. The version is **Developer Rejected** after the authorized withdrawal from review. No replacement submission has been sent.

## Diagnosed screenshot cause

A fresh App Store Connect tab reproduced the English screenshot failure while recording the browser's actual responses. Each new medium-iPhone placement returned HTTP 409, `STATE_ERROR.ASSETS_PER_PLACEMENT_LIMIT_EXCEEDED`: the placement group already contains its limit of ten screenshots.

The page's placement-list response returned only **50 of 81** records and supplied a next-page cursor. All 50 returned records were legacy screenshots: 8 iPad 13-inch, 8 iPad 12.9-inch second-generation, 5 iPad 9.7-inch, and 29 older Home-button iPhone screenshots. No modern medium-iPhone placements appeared in that first page. The UI's zero count therefore cannot be treated as evidence that earlier uploads were not saved. Repeated attempts created placements that the truncated readback did not display.

Recovery is to remove the obsolete draft placements through Media Manager, retaining their Asset Library files, then inspect and deduplicate the newly visible modern groups. The UI explicitly confirms that removal from this device leaves files in Asset Library. The first removal confirmation was opened but not completed when desktop focus changed. No removal is claimed yet. Header/search behavior will be rechecked after this cleanup rather than assumed fixed.

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

The browser extension and native uploader both exhibited the English failure. The browser connection was separately recovered by opening and closing its existing ChatGPT sidebar. Recovery did not make English placements persist.

An independent `sips` inspection found the English and successful French medium screenshots both use opaque RGB PNG, 1206 × 2622, and the same sRGB IEC61966-2.1 profile. Their header PNGs are both opaque RGB, 3840 × 1646, and use the same embedded Google/Skia profile. These checks do not explain the English-only failure.

All 20 non-English header/search pairs passed readback after a full page reload and explicit locale selection. Reloading resets the locale to English (U.S.), so that reset was accounted for during verification.

## Evidence

- [English native upload error](en-native-upload-error.jpg)
- [French screenshots persisted](fr-main-screenshots-persisted.jpg)
- [Header save error](main-artwork-save-error.jpg)
- [Non-English creative readback](non-english-creative-readback.json)
- [Current release checkpoint](../resubmission.json)

Apple's [asset management instructions](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-store-assets) list Developer Rejected as an editable upload state. The generic UI error initially concealed the placement-limit and pagination evidence documented above. No support message has been sent.
