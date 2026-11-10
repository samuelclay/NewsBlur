# Android 16.0.3 (295): F-Droid compatibility

This source release fixes [GitHub issue #2172](https://github.com/samuelclay/NewsBlur/issues/2172).
ML Kit's non-free language detector made the existing F-Droid build recipe fail.
Google Play dependencies and their implementations now live in `app/src/play`;
`-Pfdroid` selects free implementations without those SDKs. Normal Play behavior
is preserved. No Play upload is planned for this compatibility-only release;
16.0.2 (294) remains the submitted Play release.

F-Droid's onboarding recommendations keep feed recency, title, icon and content
quality checks, but no longer reject feeds based on language. Upgrade actions
open NewsBlur's website, and Play review/billing services are disabled.

Before the version bump, verification of the same implementation found:

- F-Droid's real source scanner: three fatal SDK findings before, zero afterward.
  Two pre-existing font-file warnings remain.
- Resolved release runtime graph: no ML Kit, Play Services, Play Review or Billing.
- F-Droid release APK build and 871 unit tests passed, with no failures or skips.
- Normal Play release Kotlin and Java compilation passed.
- Twelve Git-fixture regression tests passed for automatic release selection,
  merged/batched pushes and immutable remote tags; independent review found no blockers.

The GitHub `Android Release and F-Droid` workflow validates this version-bump
commit and automatically publishes its immutable `Android_16.0.3` tag after
success. See [FDROID.md](../../NewsBlur/FDROID.md) for build and release automation.

The official F-Droid repository needs the updated build recipe in
`fdroiddata.patch`. That patch adds 16.0.3 with `gradleprops: [fdroid]`, removes
`app/src/play` from the disposable export, and replaces the old source-editing
hacks with the supported build switch. The GitHub APK artifact is unsigned build
evidence. It does not establish acceptance or publication by F-Droid.
