# Android 16.0

- Version: `16.0`, version code `292`.
- Source: `69901cdd6`, tagged `Android_16.0`.
- Includes native language support in 21 languages (PR #2165), the fixed Next story controls (PR #2175, forum #13896), and legible sign-in buttons in dark themes.
- Store notes: 21 `<google-locale>.txt` files generated from `clients/store/releases/16.0/`, each under Play's 500-character limit. English is `en-US.txt`.
- Localized listing and subscription text: `clients/store/metadata/` and `clients/store/products/`. Validate and export using `clients/store/README.md`.

## Build

From `clients/android/NewsBlur`, supply the release signing key through Android Studio injected environment properties:
`ORG_GRADLE_PROJECT_android.injected.signing.store.file`, `...store.password`, `...key.alias` = `newsblur`, and `...key.password`.

```sh
env JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew --console=plain :app:testDebugUnitTest :app:bundleRelease
```

The release was built with an explicitly supplied signing secret through the injected environment properties. A populated `keystore_pw.txt` is not required for this method. Do not put signing secrets in release notes or command logs.

All 838 Android unit tests passed. The release bundle was built and its signing certificate validated against NewsBlur's upload certificate:

- Certificate SHA-256: `5C:5E:93:50:3C:6A:C4:89:88:6A:29:BE:0C:28:6B:A6:04:82:E2:C2:5A:A6:D6:EF:56:84:FD:6E:8F:D7:C3:19`.
- AAB SHA-256: `5919fdc80fe0aedf8cdd565bc9fd0ed69d049bc2ec10a58c055e58849be50cd2`.

## Play submission

Not submitted yet. Production rollout target: 100%, with managed publishing off. Validate and read back all localized store text before submitting. A successful bundle build and signing check do not establish store submission or public availability.
