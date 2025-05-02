import org.gradle.api.JavaVersion

object Config {

    const val compileSdk = 34
    const val minSdk = 26
    const val targetSdk = 35
    const val versionCode = 238
    const val versionName = "13.5.1"

    const val androidTestInstrumentation = "androidx.test.runner.AndroidJUnitRunner"

    val javaVersion = JavaVersion.VERSION_17
}