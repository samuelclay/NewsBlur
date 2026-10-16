# Android 16.0

- Version: `16.0`, version code `292`.
- Release tag: `Android_16.0` on the version bump commit.
- Includes native language support in 21 languages (PR #2165), the fixed Next story controls (PR #2175, forum #13896), and legible sign-in buttons in dark themes.
- Store notes: `en-US.txt` (under Play's 500-character limit).

## Build

From `clients/android/NewsBlur`, with the release signing key supplied as Android Studio injected properties
(`ORG_GRADLE_PROJECT_android.injected.signing.store.file`, `...store.password`, `...key.alias` = `newsblur`, `...key.password`):

`env JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew --console=plain :app:testDebugUnitTest :app:bundleRelease`

The keystore is `~/Library/Mobile Documents/com~apple~CloudDocs/NewsBlur/Secrets/Android Keystore/newsblur_android_key`. Its `keystore_pw.txt` is empty, so the passwords have to come from Sam's password manager. Verify the signing certificate SHA-256 is `5C:5E:93:50:3C:6A:C4:89:88:6A:29:BE:0C:28:6B:A6:04:82:E2:C2:5A:A6:D6:EF:56:84:FD:6E:8F:D7:C3:19` before uploading.

## Play submission

Not submitted yet. Production rollout target: 100%, with managed publishing off.
