# NB Alpha for Android

Select the `alpha` build variant in Android Studio to run the current checkout as
**NB Alpha** (`com.newsblur.alpha`). It installs alongside **NewsBlur**
(`com.newsblur`), with a separate login, database, preferences, notifications, and
file provider. Both apps use the normal NewsBlur service, so reading and other
account changes still sync between them after signing into the same account.

The default blue icon is copied unchanged from
`clients/ios/NewsBlur/Images.xcassets/AppIconDev.appiconset/App icon.png` to
`app/src/main/res/drawable-nodpi/app_icon_alpha.png`. Its adaptive foreground keeps
the star inside Android launcher masks. Alpha retains the existing icon chooser
and adds **NB Alpha** as its first option, in light, automatic, and dark modes.

## Build and install

Run Gradle from `clients/android/NewsBlur`:

```sh
env JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew :app:assembleAlpha

adb devices -l
adb -s DEVICE_SERIAL install -r app/build/outputs/apk/alpha/app-alpha.apk
adb -s DEVICE_SERIAL shell monkey -p com.newsblur.alpha \
  -c android.intent.category.LAUNCHER 1
```

Choose the physical phone's serial or its paired wireless debugging address from
`adb devices -l`. Targeting it explicitly avoids installing to another attached
emulator or device. An update with `install -r` preserves Alpha's login and data.

Alpha is a debug-signed build type using the current branch. It does not change
the existing `debug`, `release`, or `benchmark` tasks. In particular,
`:app:installDebug` still targets `com.newsblur`; use Alpha on a phone where the
production app should be kept intact. Production releases continue to use
`:app:bundleRelease` and the existing Play signing process.

## Validate both identities

```sh
env JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew :app:testAlphaUnitTest :app:testDebugUnitTest \
  :app:assembleAlpha :app:processReleaseMainManifest
```

`AppIconManifestTest.kt` checks each variant's icon catalog and default launcher.
On a device, check that both apps remain installed, Alpha's shortcuts target
Alpha, the icon chooser can switch back to the blue default, and light, dark,
black, and sepia themes retain the Alpha app label. Static shortcuts in
`app/src/alpha/res/xml/shortcuts.xml` must stay in sync with the main resource,
apart from their target package.

Initial validation on September 13, 2026: 338 unit tests passed in each of the
Alpha and debug variants. The merged release manifest retained `com.newsblur`,
its original default icon, and its file provider. Alpha installed and launched
over paired wireless debugging on a Galaxy S22 running Android 16. The existing
NewsBlur 14.3.1 installation's package path, version, and install timestamps were
identical before and after. Both launchers and Alpha's three isolated shortcuts
were also verified on the existing emulator.
