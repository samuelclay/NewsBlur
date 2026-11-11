package com.newsblur.web

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class Test_WebImagesPathHandler {
    @get:Rule
    val appStorage = TemporaryFolder()

    @Test
    fun test_a_story_cannot_read_app_files_outside_the_image_cache() {
        val imageCache = appStorage.newFolder("cache", "olimages")
        val image = File(imageCache, "12345.png").apply { writeText("image") }
        appStorage.newFolder("shared_prefs")
        appStorage.newFile("shared_prefs/preferences.xml").writeText("cookie")
        val handler = WebImagesPathHandler(imageCache)

        assertEquals(image.canonicalFile, handler.cachedImage("12345.png"))
        assertNull(handler.cachedImage("../../shared_prefs/preferences.xml"))
    }
}
