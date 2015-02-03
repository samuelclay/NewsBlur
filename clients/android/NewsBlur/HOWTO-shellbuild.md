## How To Build from the Command Line

*an abridged version of the official guide found [here](https://developer.android.com/tools/building/building-cmdline.html)*

1. install java and ant (prefer official JDK over OpenJDK)
2. download the Android SDK from [android.com](https://developer.android.com/sdk/index.html)
3. get the `tools/` and/or `platform-tools/` directories ifrom the SDK on your path
4. `android update sdk --no-ui` (this could take a while; you can use the --filter option to just get the SDK, platform tools, and support libs)
5. go to the clients/android/ NewsBlur directory and run `android update project --name NewsBlur --path .`
6. build a test APK with `ant clean && ant debug` (.apk will be in `/bin` under the working directory)
