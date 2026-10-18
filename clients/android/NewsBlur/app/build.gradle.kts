plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ktlint)
}

// app/build.gradle.kts keeps existing task and artifact names for both distributions.
val fdroid = providers.gradleProperty("fdroid").isPresent

android {
    bundle { language { enableSplit = false } }
    namespace = "com.newsblur"
    compileSdk =
        libs.versions.compileSdk
            .get()
            .toInt()

    defaultConfig {
        applicationId = "com.newsblur"
        minSdk =
            libs.versions.minSdk
                .get()
                .toInt()
        targetSdk =
            libs.versions.targetSdk
                .get()
                .toInt()
        versionCode = 296
        versionName = "16.0.4"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        manifestPlaceholders["defaultLauncherEnabled"] = "true"
        manifestPlaceholders["socialCallbackScheme"] = "newsblur-auth-android"
        manifestPlaceholders["playBillingEnabled"] = (!fdroid).toString()
    }

    buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        create("alpha") {
            initWith(getByName("debug"))
            applicationIdSuffix = ".alpha"
            matchingFallbacks += listOf("debug")
            manifestPlaceholders["defaultLauncherEnabled"] = "false"
            manifestPlaceholders["socialCallbackScheme"] = "newsblur-auth-android-alpha"
        }
        create("storecapture") {
            initWith(getByName("debug"))
            applicationIdSuffix = ".storecapture"
            matchingFallbacks += listOf("debug")
            manifestPlaceholders["defaultLauncherEnabled"] = "false"
            manifestPlaceholders["socialCallbackScheme"] = "newsblur-auth-android-storecapture"
        }
        maybeCreate("benchmark")
        getByName("benchmark") {
            signingConfig = signingConfigs.getByName("debug")
            matchingFallbacks += listOf("release")
            isDebuggable = false
            proguardFiles("benchmark-rules.pro")
        }
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            ndk {
                debugSymbolLevel = "FULL"
            }
        }
    }
    packaging {
        resources.excludes.add("META-INF/*")
    }
    // StoreCaptureActivity.kt shares the licensed cooking fixture with the iOS capture harness.
    sourceSets.getByName("storecapture").assets.srcDir("../../../ios/MarketingCooking")
    sourceSets.getByName("main").java.srcDir(if (fdroid) "src/fdroid/java" else "src/play/java")
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }
    kotlinOptions {
        jvmTarget = "21"
    }
    buildFeatures {
        compose = true
        viewBinding = true
        buildConfig = true
    }
}

ktlint {
    android = true
    ignoreFailures = false
    coloredOutput = true

    filter {
        exclude("**/generated/**", "**/build/**")
    }
}

if (!fdroid) apply(from = "src/play/dependencies.gradle")

dependencies {
    implementation(libs.androidx.fragment)
    implementation(libs.androidx.recyclerview)
    implementation(libs.androidx.swiperefreshlayout)
    implementation(libs.androidx.preference)
    implementation(libs.androidx.browser)
    implementation(libs.material)
    implementation(libs.okhttp)
    implementation(libs.gson)
    implementation(libs.lifecycle.runtime.ktx)
    implementation(libs.lifecycle.process)
    implementation(libs.androidx.core.splashscreen)
    implementation(libs.hilt.android)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.webkit)
    implementation(libs.androidx.window)
    ksp(libs.hilt.compiler)
    implementation(libs.androidx.profileinstaller)

    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.mockk)
    testImplementation(libs.sqlite.jdbc)

    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.core.ktx)

    implementation(libs.androidx.hilt.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material.icons.extended)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)

    implementation(libs.androidx.material3)
}
