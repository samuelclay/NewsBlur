import com.github.benmanes.gradle.versions.updates.DependencyUpdatesTask

plugins {
    id(Plugins.androidApplication) version Version.android apply false
    id(Plugins.androidLibrary) version Version.android apply false
    kotlin(Plugins.kotlinAndroid) version Version.kotlin apply false
    kotlin(Plugins.kotlinKapt) version Version.kotlin apply false
    id(Plugins.hiltAndroid) version Version.hilt apply false
    id(Plugins.androidTest) version Version.android apply false
    id(Plugins.benManesVersions) version Version.benManesVersions
}

allprojects {
    repositories {
        mavenCentral()
        google()
    }
}

tasks.register("clean", Delete::class) {
    delete(rootProject.layout.buildDirectory)
}

tasks.withType<DependencyUpdatesTask> {
    rejectVersionIf {
        isNonStable(candidate.version)
    }
}

fun isNonStable(version: String): Boolean {
    val stableKeyword = listOf("RELEASE", "FINAL", "GA").any { version.uppercase().contains(it) }
    val regex = "^[0-9,.v-]+(-r)?$".toRegex()
    val isStable = stableKeyword || regex.matches(version)
    return isStable.not()
}