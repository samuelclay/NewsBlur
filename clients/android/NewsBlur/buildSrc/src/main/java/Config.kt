import org.gradle.api.JavaVersion

object Config {

    const val compileSdk = 35
    const val minSdk = 26
    const val targetSdk = 35
    const val versionCode = 246
    const val versionName = "13.8.0"

    const val androidTestInstrumentation = "androidx.test.runner.AndroidJUnitRunner"

    val javaVersion = JavaVersion.VERSION_21
}