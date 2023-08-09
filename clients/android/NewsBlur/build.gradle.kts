plugins {
    id(Plugins.androidApplication) version Version.android apply false
    id(Plugins.androidLibrary) version Version.android apply false
    kotlin(Plugins.kotlinAndroid) version Version.kotlin apply false
    kotlin(Plugins.kotlinKapt) version Version.kotlin apply false
    id(Plugins.hiltAndroid) version Version.hilt apply false
    id(Plugins.androidTest) version Version.android apply false
}

allprojects {
    repositories {
        mavenCentral()
        google()
    }
}

tasks.register("clean", Delete::class) {
    delete(rootProject.buildDir)
}