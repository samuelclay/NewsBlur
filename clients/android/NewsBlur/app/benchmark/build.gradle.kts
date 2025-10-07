plugins {
    id(Plugins.androidTest)
    kotlin(Plugins.kotlinAndroid)
}

android {
    namespace = Const.namespaceBenchmark
    compileSdk = Config.compileSdk

    compileOptions {
        sourceCompatibility = Config.javaVersion
        targetCompatibility = Config.javaVersion
    }

    defaultConfig {
        minSdk = Config.minSdk
        targetSdk = Config.targetSdk

        testInstrumentationRunner = Config.androidTestInstrumentation
    }

    buildTypes {
        // This benchmark buildType is used for benchmarking, and should function like your
        // release build (for example, with minification on). It's signed with a debug key
        // for easy local/CI testing.
        maybeCreate(Const.benchmark)
        getByName(Const.benchmark) {
            isDebuggable = true
            signingConfig = signingConfigs.getByName(Const.debug)
            matchingFallbacks += listOf(Const.release)
        }
    }

    targetProjectPath = ":app"
    experimentalProperties[Const.selfInstrumenting] = true
}

dependencies {
    implementation(Dependencies.junitExt)
    implementation(Dependencies.espressoCore)
    implementation(Dependencies.uiAutomator)
    implementation(Dependencies.benchmarkMacroJunit4)
}

androidComponents {
    beforeVariants(selector().all()) {
        it.enable = it.buildType == Const.benchmark
    }
}