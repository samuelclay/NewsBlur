# Primary English asset placement failure

Observed on October 16, 2026 for NewsBlur, app ID `463981119`, iOS version `16.0`, build `343`. The version is **Developer Rejected** after the authorized withdrawal from review. No replacement submission has been sent.

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

All 20 non-English header/search pairs passed readback after a full page reload and explicit locale selection. Reloading resets the locale to English (U.S.), so that reset was accounted for during verification.

## Evidence

- [English native upload error](en-native-upload-error.jpg)
- [French screenshots persisted](fr-main-screenshots-persisted.jpg)
- [Header save error](main-artwork-save-error.jpg)
- [Non-English creative readback](non-english-creative-readback.json)
- [Current release checkpoint](../resubmission.json)

Apple's [asset management instructions](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-store-assets) list Developer Rejected as an editable upload state. The UI does not expose a more specific cause. This evidence establishes a primary-locale placement failure, not its server-side cause. No support message has been sent.
