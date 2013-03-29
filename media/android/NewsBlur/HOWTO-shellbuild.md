## How To Build from the Command Line

*an abridged version of the official guide found [here](https://developer.android.com/tools/building/building-cmdline.html)*

1. install java and ant
2. download the Android SDK from [android.com](https://developer.android.com/sdk/index.html) (the full ADT bundle in fine, too)
3. get the `tools/` and/or `platform-tools/` directories on your path
4. `android update sdk --no-ui` (this could take a while)
5. go to both of the following NewsBlur directories and run `android update project --path .`:
  * `NewsBlur/media/android/NewsBlur/`
  * `NewsBlur/media/android/NewsBlur/libs/ActionBarSherlock/`
6. build a test APK with `ant clean && ant debug` from `NewsBlur/media/android/NewsBlur/` (.apk will be in `NewsBlur/media/android/NewsBlur/bin/`)
