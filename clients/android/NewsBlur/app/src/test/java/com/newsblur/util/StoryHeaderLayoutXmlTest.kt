package com.newsblur.util

import java.nio.file.Files
import java.nio.file.Paths
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Test

class StoryHeaderLayoutXmlTest {
    @Test
    fun compact_header_labels_do_not_inherit_tall_material_button_spacing() {
        val layoutPath = Paths.get("src/main/res/layout/activity_itemslist.xml")
        val document =
            Files.newInputStream(layoutPath).use { input ->
                DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(input)
            }
        val nodes = document.getElementsByTagName("com.google.android.material.button.MaterialButton")
        var headerPillCount = 0

        for (index in 0 until nodes.length) {
            val attributes = nodes.item(index).attributes
            val id = attributes.getNamedItem("android:id").nodeValue
            if (!id.endsWith("_pill")) continue
            headerPillCount++
            // ItemsList.java captures spacing before clearing Material insets; both states must fit the same 28 dp pill.
            for (attribute in listOf("paddingTop", "paddingBottom", "insetTop", "insetBottom")) {
                assertEquals("$id $attribute", "0dp", attributes.getNamedItem("android:$attribute")?.nodeValue)
            }
            assertEquals("$id single line", "true", attributes.getNamedItem("android:singleLine")?.nodeValue)
            assertEquals("$id centering", "center", attributes.getNamedItem("android:gravity")?.nodeValue)
        }
        assertEquals(3, headerPillCount)
    }

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
