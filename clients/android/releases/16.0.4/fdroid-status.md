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

The replacement metadata change is prepared locally for the author's
`samuelclay/fdroiddata` fork. The existing bot branch cannot be edited with the author's permissions.
The replacement will explicitly supersede !51902, without closing that request.
Publication of the metadata request waits for the release workflow to validate
the exact 16.0.4 source commit and publish its immutable tag.
