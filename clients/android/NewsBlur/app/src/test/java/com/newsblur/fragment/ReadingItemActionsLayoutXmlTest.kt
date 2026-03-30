package com.newsblur.fragment

import java.nio.file.Files
import java.nio.file.Paths
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Test

class ReadingItemActionsLayoutXmlTest {
    @Test
    fun actionsContainerStartsHiddenUntilStoryRenderCompletes() {
        val layoutPath = Paths.get("src/main/res/layout/reading_item_actions.xml")
        val document =
            Files.newInputStream(layoutPath).use { input ->
                DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(input)
            }
        val nodes = document.getElementsByTagName("LinearLayout")

        for (index in 0 until nodes.length) {
            val node = nodes.item(index)
            val attributes = node.attributes
            if (attributes.getNamedItem("android:id")?.nodeValue == "@+id/actions_container") {
                assertEquals("gone", attributes.getNamedItem("android:visibility")?.nodeValue)
                return
            }
        }

        throw AssertionError("actions_container not found in reading_item_actions.xml")
    }
}
