# Building the NewsBlur Android App

The NewsBlur Android application should build with virtually any supported Android build tool or environement.  The file structure found in this repo has been chosen for maximum compatibility with various development setups.  Several examples of how to build can be found below.

It is the goal of this repository to stay agnostic to build environments or tools.  Please consider augmenting the .gitignore file to catch any developer-specific build artifacts or environment configuration you may discover while building.

## How to Build from the Command Line with Ant

*an abridged version of the official guide found [here](https://developer.android.com/tools/building/building-cmdline.html)*

*this type of build will use the vendored dependencies in `clients/android/NewsBlur/libs`*

1. install java and ant (prefer official JDK over OpenJDK)
2. download the Android SDK from [android.com](https://developer.android.com/sdk/index.html)
3. get the `tools/` and/or `platform-tools/` directories ifrom the SDK on your path
4. `android update sdk --no-ui` (this could take a while; you can use the --filter option to just get the SDK, platform tools, and support libs)
5. go to the clients/android/ NewsBlur directory and run `android update project --name NewsBlur --path .`
6. build a test APK with `ant clean && ant debug` (.apk will be in `/bin` under the working directory)

## How to Build from the Command Line with Gradle

*this type of build will pull dependencies as prescribed in the gradle configuration*

1. install gradle v2.8 or better
2. build a test APK with `gradle build` (.apk will be in `/build/outputs/apk/` under the working directory)

## How to Build from Android Studio

*this type of build will pull dependencies as prescribed in the gradle configuration*

1. install and fully update [Android Studio](http://developer.android.com/tools/studio/index.html)
2. run AS and choose `import project`
3. within your local copy of this repo, select the directory/path where this file is located
4. select `OK` to let AS manage Gradle for your project
6. select `Build -> Make Project from the menu`
7. select `Build -> Build APK from the menu`

## Building Releases

*tip: a debug-compatible release key is usually located at `~/.android/debug.keystore` with the alias `androiddebugkey` and the passwords `android`.*

### Ant Builds

* Create a `local.properties` file with the following values:

```
has.keystore=true
key.store=<path to your keystore file>
key.alias=<alias of the key with which you would like to sign the APK>
```

* run `ant clean && ant release`

### Gradle Builds

* Add the following lines to the `android` section of the `build.gradle` file:

```
signingConfigs {
    release {
        storeFile file('<absolute path to your keystore file>')
        keyAlias '<alias of the key with which you would like to sign the APK>'
        storePassword '<keystore password>'
        keyPassword '<key password>'
    }
}
buildTypes.release.signingConfig = signingConfigs.release
```

* run `gradle assembleRelease`

### Android Studio Builds

* See the AS documentation on [signing release builds](http://developer.android.com/tools/publishing/app-signing.html#studio)
