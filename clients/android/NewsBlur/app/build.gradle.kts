plugins {
    id(Plugins.androidApplication)
    kotlin(Plugins.kotlinAndroid)
    kotlin(Plugins.kotlinKapt)
    id(Plugins.hiltAndroid)
}

android {
    namespace = Const.namespace
    compileSdk = Config.compileSdk

    defaultConfig {
        applicationId = Const.namespace
        minSdk = Config.minSdk
        targetSdk = Config.targetSdk
        versionCode = Config.versionCode
        versionName = Config.versionName

        testInstrumentationRunner = Config.androidTestInstrumentation
    }

    buildTypes {
        getByName(Const.debug) {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        maybeCreate(Const.benchmark)
        getByName(Const.benchmark) {
            signingConfig = signingConfigs.getByName(Const.debug)
            matchingFallbacks += listOf(Const.release)
            isDebuggable = false
            proguardFiles(Const.benchmarkProguard)
        }
        getByName(Const.release) {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile(Const.defaultProguard), Const.appProguard)
        }
    }
    packaging {
        resources.excludes.add("META-INF/*")
    }
    compileOptions {
        sourceCompatibility = Config.javaVersion
        targetCompatibility = Config.javaVersion
    }
    buildFeatures {
        viewBinding = true
        buildConfig = true
    }
}

dependencies {
    implementation(Dependencies.fragment)
    implementation(Dependencies.recyclerView)
    implementation(Dependencies.swipeRefreshLayout)
    implementation(Dependencies.okHttp)
    implementation(Dependencies.gson)
    implementation(Dependencies.billing)
    implementation(Dependencies.playReview)
    implementation(Dependencies.material)
    implementation(Dependencies.preference)
    implementation(Dependencies.browser)
    implementation(Dependencies.lifecycleRuntime)
    implementation(Dependencies.lifecycleProcess)
    implementation(Dependencies.splashScreen)
    implementation(Dependencies.hiltAndroid)
    kapt(Dependencies.hiltCompiler)
    implementation(Dependencies.profileInstaller)

    testImplementation(Dependencies.junit)
    testImplementation(Dependencies.mockk)

    androidTestImplementation(Dependencies.junitExt)
    androidTestImplementation(Dependencies.espressoCore)
}