# F-Droid builds and Android release tags

The default build uses Google Play billing, review prompts and ML Kit onboarding
language checks. Pass `-Pfdroid` to select the free distribution instead:

```sh
./gradlew -Pfdroid -Pci :app:testDebugUnitTest :app:assembleRelease
```

The unsigned APK is `app/build/outputs/apk/release/app-release-unsigned.apk`.
Existing task names and the `com.newsblur` application ID are unchanged. F-Droid
upgrades open NewsBlur's website, review prompts and billing synchronization are
disabled, and onboarding retains its feed quality checks without rejecting feeds
based on language. Play builds retain their existing behavior.

## Source scanning

Play-only code and dependency declarations live in `app/src/play`. F-Droid's
metadata must remove that directory from its disposable checkout before scanning
and pass `fdroid` through `gradleprops`. Do not delete it from a development checkout.
The older metadata recipe that edits Kotlin files with `sed` must be replaced;
publishing a new tag alone does not update F-Droid's build recipe.

The GitHub workflow runs `ci/check_fdroid_source.py` with fdroidserver 2.4.5 against
the source export, checks the resolved release dependency graph with
`ci/check_fdroid_dependencies.sh`, runs unit tests, and builds an unsigned APK.
The source scanner is for disposable exports because it may remove artifacts.
The workflow artifact is build evidence; F-Droid builds and signs its official
package separately after accepting the metadata update.

## Automatic release tags

`.github/workflows/android-release.yml` runs on Android changes on main, pull
requests, manually requested checks, and externally pushed `Android_*` tags.
Every stable version bump on main selects the exact commit that changed both
`versionName` and `versionCode`. After its F-Droid checks pass, the workflow pushes
`Android_<versionName>` at that commit. Later documentation or source commits do
not move an existing tag. Both version fields must increase.

Normal releases need only push the authorized version bump to main, then verify
the workflow and remote tag. The workflow performs F-Droid checks before creating
the tag because tags pushed with `GITHUB_TOKEN` do not start another workflow.
It never forces or replaces tags. A mismatched existing tag fails visibly.

For a historical missing tag, run this workflow on main with `backfill_tag=true`.
It selects the original bump commit of the current version, validates that source,
and creates the tag only if it is absent. The historical commit must already
contain the F-Droid build support and CI helpers. Otherwise inspect and publish
that historical tag explicitly instead of moving it to a newer compatibility fix.

Tests for source selection, merged/batched commits and immutable remote tags:

```sh
node --test clients/android/NewsBlur/ci/release_tag.test.mjs
```
