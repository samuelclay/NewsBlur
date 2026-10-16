# NewsBlur 16.0 release verification

Prepared from source commit `69901cdd6`, tagged `iOS_16.0` and `Android_16.0`. Store copy is maintained separately from the tagged app binaries.

| Platform | Version | Build | Preparation evidence |
| --- | --- | --- | --- |
| iOS | 16.0 | 343 | Release archive built with public Xcode 27.0 |
| Android | 16.0 | 292 | 838 unit tests passed; release AAB built and upload certificate validated |

Android AAB SHA-256: `5919fdc80fe0aedf8cdd565bc9fd0ed69d049bc2ec10a58c055e58849be50cd2`.

## Translation review

The English listing and release notes were rewritten first, then translated in three parallel batches. Other agents reviewed each translation against the English source and app glossaries:

- Western: Spanish, French, German, Brazilian Portuguese, Italian, Dutch, Polish.
- Central: Turkish, Russian, Ukrainian, Arabic, Hebrew, Hindi, Indonesian.
- Asian: Vietnamese, Thai, Japanese, Korean, Simplified Chinese, Traditional Chinese.

The canonical set contains all 21 app-supported languages, including English: 210 listing/release fields and 420 subscription/group fields, for 630 total. The Ruby validator passes all fields, including store character limits, Apple's UTF-8 keyword byte limit, exact locale/product coverage, control character checks, preserved brands, and canonical URLs.

Independent review reports are retained in `reviews/`. Corrections included matching actual Android Next/Done labels, avoiding an ambiguous Android settings menu name, preserving the meaning of hiding unwanted stories, improving Russian/Ukrainian and Hindi phrasing, and ensuring product text explicitly describes tagging saved articles. Vietnamese and Chinese product wording was clarified. Account requirements, optional paid plans, AI usage limits, Apple renewal disclosures, and the distinction between interface localization and untranslated story content were retained.

Export verification covered 21 listing/release locales, 63 Apple subscription localizations, 21 Apple subscription-group localizations, and 42 Google subscription listings. Isolated malformed fixtures were rejected for oversized UTF-8 keywords, oversized titles, missing fields, hidden directional controls, missing languages, and missing products. No strings were truncated to satisfy a limit.

## Store status

### iOS

Submitted on October 16, 2026 at 11:05 AM PDT. [App Review submission 7d9b11c7-4321-47a3-a56c-57c0c21edb67](https://appstoreconnect.apple.com/apps/463981119/distribution/reviewsubmissions/details/7d9b11c7-4321-47a3-a56c-57c0c21edb67) shows **Waiting for Review** for all five items:

- iOS 16.0, build 343.
- Premium, Archive, and Pro subscriptions.
- Subscription group `20421002`.

All 21 app and version localizations, all 63 subscription localizations, and all 21 subscription-group localizations were saved and read back against the canonical files. The existing British English Premium localization was also updated. Product identifiers, billing periods, prices, and offers were preserved. Automatic release after approval is selected, with immediate availability to all users rather than phased release. Submission does not mean approval or public availability.

### Android

The signed 16.0 bundle (version code 292), 21 store listings, and 21 release-note localizations are staged and verified in an uncommitted Play API edit. Subscription text and production submission are still in progress; Android is not yet submitted.

Screenshot assets and linked privacy/terms documents have not been translated by this text workflow.
