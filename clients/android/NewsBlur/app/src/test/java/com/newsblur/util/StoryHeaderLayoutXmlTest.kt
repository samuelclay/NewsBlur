package com.newsblur.util

import java.nio.file.Files
import java.nio.file.Paths
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Test

class StoryHeaderLayoutXmlTest {
    @Test
    fun options_pill_has_extra_icon_padding() {
        val layoutPath = Paths.get("src/main/res/layout/activity_itemslist.xml")
        val document =
            Files.newInputStream(layoutPath).use { input ->
                DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(input)
            }
        val nodes = document.getElementsByTagName("com.google.android.material.button.MaterialButton")

        for (index in 0 until nodes.length) {
            val node = nodes.item(index)
            val attributes = node.attributes
            if (attributes.getNamedItem("android:id")?.nodeValue == "@+id/itemlist_options_pill") {
                assertEquals("4dp", attributes.getNamedItem("app:iconPadding")?.nodeValue)
                return
            }
        }

        throw AssertionError("itemlist_options_pill not found in activity_itemslist.xml")
    }
}
