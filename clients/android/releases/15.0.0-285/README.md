# Android 15.0.0 (285) contact policy correction

## Build

- Version name: `15.0.0`; version code: `285`.
- Source: `912e7980b8abe6d0786bfd29b2e6428fa6054ad4`.
- Pushed tag: `Android_15.0.0`. Previous build 284's source remains available under `Android_15.0.0_284`.
- Signed release bundle built with Android Studio's JBR using `:app:testDebugUnitTest :app:bundleRelease`.
- All 472 unit tests pass. Release lint and optimization pass; archive integrity and JAR signature verify.
- Signing certificate SHA-256 matches the previous Play bundle: `5C:5E:93:50:3C:6A:C4:89:88:6A:29:BE:0C:28:6B:A6:04:82:E2:C2:5A:A6:D6:EF:56:84:FD:6E:8F:D7:C3:19`.
- Bundle SHA-256: `5d625faed5965917fe0a8736b19ed0550d72a921bf3a8660eb7c331fa340db85`.
- Bundle size: 11,300,160 bytes.
- Archived in `~/Library/Mobile Documents/com~apple~CloudDocs/NewsBlur/Android/Builds/` as `NewsBlur-15.0.0-285.aab`, with matching mapping and testing-notes files.
- [Release notes](en-US.txt): 490 characters excluding final newline.

## Policy correction

Adds a native Contact us page accessible from the main menu and login screen. Contact details remain visible without login, network access, or an email app. [Device verification and four-theme screenshots](../contact-policy-fix/README.md).

Website commits `65ca4bcdc` and `e61430b67` are on main. They add `/contact` and links from the footer and About page. Both website regression tests pass on main.

## Deployment and submission

- Website deployed on September 16, 2026 using `make deploy_static` from main. Final Ansible recap: all 14 app hosts succeeded with zero failures or unreachable hosts. Public https://www.newsblur.com/contact returns HTTP 200, renders correctly, and includes both email addresses and the footer link.
- Initial deployment needed two environment corrections: use the existing NewsBlur virtualenv on the local PATH for boto3, and explicitly fetch the moved Android tag on app hosts. After the tag-fetch interruption, Group A was re-enabled and verified healthy before the full deployment retry.
- News and magazine apps declaration now points to https://www.newsblur.com/contact. Existing NewsBlur, Inc., Commercial / private, and news aggregator answers remain accurate.
- Store listing already has https://www.newsblur.com, samuel@newsblur.com, and News & Magazines; no changes were necessary there.
- Uploaded and submitted build `285 (15.0.0)` to **open testing**, with 100% rollout to that testing track. No production release was submitted.
- Play validation: no blocking errors or loss of supported devices. The existing native-debug-symbol recommendation remains a non-blocking warning; ReTrace mapping is attached.
- Verified **Changes in review** after refreshing the page following submission. Google review/availability is still pending; managed publishing remains off.
- [Publishing overview](https://play.google.com/console/u/3/developers/6280481402178293168/app/4972990522498280751/publishing)
- [Release review](https://play.google.com/console/u/3/developers/6280481402178293168/app/4972990522498280751/tracks/4698162496597079541/releases/98/review)
