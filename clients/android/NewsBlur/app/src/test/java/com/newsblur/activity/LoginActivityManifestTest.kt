package com.newsblur.activity

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertNotEquals
import org.junit.Test

class LoginActivityManifestTest {
    @Test
    fun loginActivity_isNotNoHistory() {
        val manifestFile =
            sequenceOf(
                File("app/src/main/AndroidManifest.xml"),
                File("src/main/AndroidManifest.xml"),
            ).firstOrNull(File::exists)

        val resolvedManifestFile = manifestFile ?: error("Could not locate app AndroidManifest.xml")
        val manifest =
            DocumentBuilderFactory
                .newInstance()
                .newDocumentBuilder()
                .parse(resolvedManifestFile)
        val activities = manifest.getElementsByTagName("activity")
        var loginNoHistory: String? = null

        for (index in 0 until activities.length) {
            val activity = activities.item(index)
            val attributes = activity.attributes
            if (attributes.getNamedItem("android:name")?.nodeValue == ".activity.LoginActivity") {
                loginNoHistory = attributes.getNamedItem("android:noHistory")?.nodeValue
                break
            }
        }

        assertNotEquals("true", loginNoHistory)
    }
}
