# Isolated Play Store capture app

`storecapture` is debug signed, installs as `com.newsblur.storecapture`, and shares
neither the production nor Alpha app's preferences, database, or login. Its
launcher renders NewsBlur's real native screens using the original fictional
cooking dataset and licensed photography in `clients/ios/MarketingCooking`.
Those assets and the capture activity are absent from release APKs.

Both API and image OkHttp clients intercept every request in this variant.
Unknown reads fail closed and writes return a local success response. The variant
also removes the `INTERNET` permission as an independent safeguard. No request
is passed to a production server. Article photographs are embedded offline.

Build with the usual Android Studio JDK:

```sh
env JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:assembleStorecapture
```

Install on an already attached device. Force stop **only this isolated package**
before each capture to reset native navigation and avoid the previous locale's
activity surviving. Launch with one of `feeds`, `stories`, `reader`, or `saved`:

```sh
adb -s DEVICE shell am force-stop com.newsblur.storecapture
adb -s DEVICE shell am start -n com.newsblur.storecapture/com.newsblur.marketing.StoreCaptureActivity --es language fr --es screen stories
```

`language` accepts the 21 native language tags in `LanguageSettings.kt`, including
`pt-BR`, `zh-Hans`, and `zh-Hant`. The app interface changes language; fictional
feed names and original editorial story content retain their original English.
Wait for the real screen and photographs to finish rendering before capturing.
The ordinary interactive UI remains usable for screen recordings.
