# Android 16.0.4 (296): F-Droid submission

The metadata patch adds `Android_16.0.4` with the supported `fdroid` Gradle
property and removes `app/src/play` before F-Droid scans the disposable source
checkout. It replaces the old recipe's source rewriting with the free build
implementations introduced in 16.0.3.

## Verified before submission

On October 17, 2026, the [public F-Droid package API](https://f-droid.org/api/v1/packages/com.newsblur)
still offered 15.0.5 (290), 15.0.4 (289), and 15.0.3 (288), with 290 suggested.
The [upstream metadata](https://gitlab.com/fdroid/fdroiddata/-/blob/master/metadata/com.newsblur.yml)
also stopped at 15.0.5. The 16.0.3 source tag and successful compatibility build
did not establish publication in the official F-Droid repository.

The existing [bot merge request !51902](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/51902)
targets version code 291. Its [build failed](https://gitlab.com/fdroid/checkupdates-bot-fdroiddata/-/jobs/17076913421)
because the old recipe left `com.google.mlkit` in `app/build.gradle.kts` during
source scanning. No open 16.0.3 submission was found.

The release patch applies cleanly to upstream metadata, parses as YAML, and
selects 16.0.4 (296), `Android_16.0.4`, the `fdroid` property, and the Play-source
exclusion. These checks validate the recipe; F-Droid still needs to build, sign,
and publish its own APK.

## Submission state

The [release workflow](https://github.com/samuelclay/NewsBlur/actions/runs/39076913158)
passed source scanning, dependency checks, tests, and the unsigned F-Droid APK
build. It published `Android_16.0.4` at the exact version-bump commit
`1b32c5b65bdf577402c055d34246691d53e534d9`; the remote tag was independently verified.

[F-Droid merge request !52997](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/52997)
is open from `samuelclay/fdroiddata:newsblur-16.0.4-fdroid`. Its head is
`af77766bf8aafa0074a8bc3b291712d18d3785b0`. The live diff changes only
`metadata/com.newsblur.yml`, and its description explicitly supersedes !51902.
The bot request remains open. The author's fork master was not changed.

The [merge-request pipeline](https://gitlab.com/samuelclay/fdroiddata/-/pipelines/2959283737)
passed all nine checks on the current head: source code, schema validation,
tool scripts, canonical metadata formatting, lint, repository redirect, update
detection, the F-Droid build, and APK inspection. The build log confirms
`com.newsblur:296` was built from the exact source commit above.

Submission and CI validation are complete. Upstream acceptance, the official
signed F-Droid build, and public availability of 16.0.4 remain pending. At
submission, the public package API reported 15.0.5 (290) as the suggested version.
