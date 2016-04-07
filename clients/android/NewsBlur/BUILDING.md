# Building the NewsBlur Android App

The NewsBlur Android application should build with virtually any supported Android build tool or environement.  The file structure found in this repo has been chosen for maximum compatibility with various development setups.  Several examples of how to build can be found below.

It is the goal of this repository to stay agnostic to build environments or tools.  Please consider augmenting the .gitignore file to catch any developer-specific build artifacts or environment configuration you may discover while building.

## How to Build from the Command Line with Ant

*an abridged version of the official guide found [here](https://developer.android.com/tools/building/building-cmdline.html)*

1. install java and ant (prefer official JDK over OpenJDK)
2. download the Android SDK from [android.com](https://developer.android.com/sdk/index.html)
3. get the `tools/` and/or `platform-tools/` directories ifrom the SDK on your path
4. `android update sdk --no-ui` (this could take a while; you can use the --filter option to just get the SDK, platform tools, and support libs)
5. go to the clients/android/ NewsBlur directory and run `android update project --name NewsBlur --path .`
6. build a test APK with `ant clean && ant debug` (.apk will be in `/bin` under the working directory)

## How to Build from the Command Line with Gradle

*gradle support is intentionally minimal and your environment may require additional preparation*

1. install gradle v1.5 or better
2. build a test APK with `gradle build` (.apk will be in `/build/outputs/apk/` under the working directory)

## How to Build from Android Studio

1. install and fully update [Android Studio](http://developer.android.com/tools/studio/index.html)
2. run AS and choose `import project`
3. within your local copy of this repo, select the directory/path where this file is located
4. uncheck `replace jars with dependencies` or `replace library sources with dependencies`
5. select `finish`
6. select `Build -> Make Project from the menu`
7. select `Build -> Build APK from the menu`

