# Mainland China availability correction and resubmission

Apple rejected iOS 16.1.1 (354) on November 4, 2026 under Guideline 2.1 because the app was selected for mainland China distribution without a publishing permit. The user confirmed that no permit is held and explicitly authorized removing mainland China.

Removed only China mainland through App Store Connect's App Availability settings. The confirmation named China mainland, and the saved page showed 174 selected countries and regions, down from 175. Apple states that availability changes can take up to 24 hours to appear. This is an app-level availability setting shared by its Apple platforms.

Updated the administrative review notes with this resolution and resubmitted the existing iOS version 16.1.1 and build 354 at 2026-11-05 06:08:37 UTC (November 4 at 22:08 Pacific). Authenticated UI and API readback confirmed Waiting for Review for the app and the two existing Archive and Pro subscription items. Automatic release after approval remains enabled.

No code change, new binary, or release tag change was needed. All 21 existing version metadata localizations were read back and match the prior submission. The original source remains `aa45aa8a5944fdea184cb5b6e6294a646c62f39c`, tagged `iOS_16.1.1_354`.

`before.json` records the rejected submission. `submission.json` contains the final API state, build, review notes, locale comparison result, review items, and authenticated availability UI observations. The API key cannot access app availability, so the territory change was made and verified in the signed-in UI.
