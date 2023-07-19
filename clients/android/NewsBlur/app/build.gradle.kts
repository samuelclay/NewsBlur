plugins {
    id ("com.android.application")
    kotlin("android")
    kotlin("kapt")
    id ("com.google.dagger.hilt.android")
}

android {
    namespace = "com.newsblur"
    compileSdk = 33

    defaultConfig {
        applicationId = "com.newsblur"
        minSdk = 23
        targetSdk = 33
        versionCode = 210
        versionName = "13.0.0b3"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
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
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
    packaging {
        resources.excludes.add("META-INF/*")
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        viewBinding = true
    }
}

dependencies {
    implementation("androidx.fragment:fragment-ktx:1.5.7")
    implementation("androidx.recyclerview:recyclerview:1.3.0")
    implementation("androidx.swiperefreshlayout:swiperefreshlayout:1.1.0")
    implementation("com.squareup.okhttp3:okhttp:4.10.0")
    implementation("com.google.code.gson:gson:2.10")
    implementation("com.android.billingclient:billing:6.0.0")
    implementation("com.google.android.play:core:1.10.3")
    implementation("com.google.android.material:material:1.9.0")
    implementation("androidx.preference:preference-ktx:1.2.0")
    implementation("androidx.browser:browser:1.5.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.6.1")
    implementation("androidx.lifecycle:lifecycle-process:2.6.1")
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("com.google.dagger:hilt-android:2.44.2")
    kapt("com.google.dagger:hilt-compiler:2.44.2")
    implementation("androidx.profileinstaller:profileinstaller:1.3.1")

    testImplementation("junit:junit:4.13.2")
    testImplementation("io.mockk:mockk:1.13.4")

    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
}