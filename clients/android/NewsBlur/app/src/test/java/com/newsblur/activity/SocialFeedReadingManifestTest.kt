package com.newsblur.activity

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Test

class SocialFeedReadingManifestTest {
    @Test
    fun socialFeedReading_handles_rotation_like_other_reading_activities() {
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
        var configChanges: String? = null

        for (index in 0 until activities.length) {
            val activity = activities.item(index)
            val attributes = activity.attributes
            if (attributes.getNamedItem("android:name")?.nodeValue == ".activity.SocialFeedReading") {
                configChanges = attributes.getNamedItem("android:configChanges")?.nodeValue
                break
            }
        }

        assertEquals(
            "orientation|screenSize|smallestScreenSize|screenLayout|keyboard|keyboardHidden",
            configChanges,
        )
    }
}
