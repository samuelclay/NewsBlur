# iOS 16.1.1 resubmission, build 354

Submitted November 3, 2026 at 08:11 Pacific. Authenticated App Store Connect UI and API both confirmed **Waiting for Review** for iOS 16.1.1 (354), alongside the existing Archive and Pro subscription text updates. Automatic release after approval remains selected. This is not approval or public availability.

Apple's Guideline 4 rejection concerned another information form after Sign in with Apple. New Apple accounts now receive a generated NewsBlur username and use Apple's verified email, including private relay addresses. The app proceeds without a required name, email, username, or password form. Existing-account linking still verifies ownership. Users can later change the generated username in NewsBlur's web Account Settings. Google and password signup retain their existing behavior. No backend deployment was needed.

The regression failed before implementation. All 46 onboarding tests passed on the final production source, and all 61 backend authentication tests passed. The hosted-view dismissal test passed separately after improving screenshot readiness; its screenshots show isolated fixtures, not a live Apple authorization round trip. Localization translate, check, and compile passed with no missing translations. All 21 existing store metadata locales were preserved and read back without mismatches.

Fix: `d198af6aed`. Release source: `aa45aa8a5944fdea184cb5b6e6294a646c62f39c`, tag `iOS_16.1.1_354`. The original `iOS_16.1.1` tag remains unchanged. Test-only screenshot readiness correction: `4d6d0b06fe`.

The public Xcode 27.0 archive succeeded, deep strict archive signature validation passed, all five extensions report build 354, and App Store export/upload succeeded. Apple processed build `3e71c1b4-7df7-43d3-814e-676078bde624` as VALID and the existing review record now references it.

Full GitHub CI status at the submission checkpoint is recorded in `ci-checkpoint.json`; local focused tests above completed successfully. macOS 16.1.1 was already Ready for Sale and was not resubmitted.
