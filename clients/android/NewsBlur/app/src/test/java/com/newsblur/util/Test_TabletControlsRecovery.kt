package com.newsblur.util

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

class Test_TabletControlsRecovery {
    private fun document(path: String) = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(
        sequenceOf(File("app/src/main/$path"), File("src/main/$path")).first(File::exists),
    )

    @Test
    fun test_feed_toolbar_has_its_own_accessible_fullscreen_control() {
        val views = document("res/layout/activity_main.xml").getElementsByTagName("androidx.appcompat.widget.AppCompatImageButton")
        val control = (0 until views.length).map { views.item(it) as Element }.find {
            it.getAttribute("android:id") == "@+id/main_fullscreen_button"
        }
        // activity_main.xml must expose the feed control independently of Reading.kt's button.
        assertTrue("The feed-list toolbar has lost its fullscreen button", control != null)
        assertTrue("The fullscreen button needs an accessible label", control!!.getAttribute("android:contentDescription").isNotBlank())
    }

}
