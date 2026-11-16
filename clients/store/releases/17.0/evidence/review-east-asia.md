# NewsBlur 17.0 independent translation review

Reviewed locales produced by other agents: tr, ru, uk, ar, he, hi, id, vi, th, ja, ko, zh-Hans, zh-Hant.

Scope: every iOS/macOS/Android listing field, 17.0 release notes, and all subscription/group product copy. Compared against finalized English, localization guidance and glossary terminology, and current native filter and preference labels in iOS Localizable.strings and Android strings.xml. Reviewed platform-specific Mac reading, keyboard, widget, audio and language details separately from phone/tablet descriptions.

Corrections made in metadata and 17.0 release files only:

- Matched actual filter-control names: Turkish Saved; Russian Saved and Android Unread; Ukrainian Apple Saved and Android Unread; Arabic labels for all four modes; Hebrew Apple Saved; Hindi Saved; Indonesian Android Saved. Generic references to saved articles were preserved.
- Rephrased Hebrew release openings to begin with Hebrew text, avoiding a Latin first-strong character in auto-direction paragraphs. Preserved brands, URLs and native punctuation without hidden direction controls.
- Corrected Vietnamese folder-reading wording to aggregate articles instead of sites. Made retained fades explicit as both gradual appearance and disappearance in descriptions, promotion and release notes.

Products required no correction. Immutable product/group IDs and configuration were preserved. Reviewed Premium qualifications, Archive's 1 hour and Pro's 10 hours of weekly listening, Sunday allowance reset, and free/Premium 30-second previews against English. All new feature claims retain ordered entrances, responsive filters, the default-off Appearance preference, movement removal with fades retained, and relevant platform-specific discovery/dialog/reader improvements.

Arabic/Hebrew text was reviewed for direction-sensitive prose, labels, punctuation and embedded Latin names. Simplified and Traditional Chinese were checked separately for script and regional terminology. This is a text/source review, not an app-store rendering or screenshot review.

Validation passed across the complete 21-language catalog:

- `ruby clients/store/validate.rb 17.0`: 630 fields, including 390 in the assigned locales.
- `ruby clients/store/validate.rb 17.0 --platform macos`: 294 fields, including 182 in the assigned locales.
- `git diff --check -- clients/store`: clean.
- Assigned-locale maxima: Apple promotion 168/170 characters; iOS description 3159/4000; macOS description 3440/4000; keywords 95/100 UTF-8 bytes; Android full description 2647/4000 and release notes 425/500. All other listing and product fields pass their limits, field shape, brand, URL and control-character checks. Shared Apple names/subtitles match.

Detailed field counts and reviewed English SHA-256 values: `/tmp/newsblur17-review-east-asia-validation.json`.

No commits, browser operations or store mutations performed. No unresolved text issues identified in this assigned review.
