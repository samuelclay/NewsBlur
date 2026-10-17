# Android 16.0.2

Version 16.0.2, code 294 replaces the unsubmitted 16.0.1 (293) draft. It includes the recovered three independent tablet fullscreen controls, saved pane widths, a quiet resize border, and the approved live-guide fallback for older Android window extensions. On those devices, the guide tracks the finger and commits the exact chosen width on release, avoiding queued native resize animations.

Submitted to Google Play on October 17, 2026 for a full production rollout. Publishing overview shows **Changes in review**, with automated quick checks still running and managed publishing off. Approval and public availability have not yet been verified. The only submitted change is production release 16.0.2. Bundle 293 was removed from the draft; its existing tag and library artifact remain unchanged. The previous 16.0 (292) rollout was halted with 15.1 (291) as fallback.

All 21 release-note translations are reused byte-for-byte from the reviewed 16.0.1 notes because their feature description remains accurate. Canonical notes are in `clients/store/releases/16.0.2/`; Play exports are beside this README. Read-back verified every localized release note, all 21 store listings, and both subscriptions in all 21 languages. Existing artwork, video URLs, product IDs, pricing and billing configuration are retained.

Source and tag: `0094bd4f869ce70e7286211ff6f3808edb2af156`, `Android_16.0.2`, pushed to GitHub and pulled onto ClayBook. All 871 local unit tests passed with no failures, errors or skips. The signed bundle's version, upload certificate and SHA-256 were verified; see `proof/build-validation.json`. Play reported no lost supported devices and one nonblocking warning about missing native debug symbols. The ReTrace mapping is included.

Fresh Alpha and regular debug APKs were installed on the Samsung SM-X200 without clearing app data. Both report 16.0.2 (294), and their installed SHA-256 hashes match the fresh build outputs. The divider guide and exact released width were checked again, including width persistence after restarting. Earlier captures cover both dividers, cancellation, Arabic/Hebrew direction, fullscreen controls and light/dark/black/sepia colors. Tablet auto-rotation, Wi-Fi and pointer-display settings were restored.

Device evidence and regression tests are in `clients/android/Performance/tablet-controls-recovery-2026-10-17/drag-regression/`.
