package com.newsblur.fragment

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element
import java.nio.file.Files
import java.nio.file.Paths
import javax.xml.parsers.DocumentBuilderFactory

// Test_AiClassifierSectionState.kt: AiClassifierSections.kt inflates include_ai_classifier_section.xml
// twice, for text and for images, so both copies share its ids. When the activity is recreated,
// Android restores saved view state by id, and the image copy's state lands in both: the image
// prompt's draft shows up in the text box and Save commits it as a billed text prompt. The app has
// no Robolectric to recreate the sheet, so this checks the layout keeps that state from being saved.
class Test_AiClassifierSectionState {
    // Plain layouts and images keep no state of their own to restore.
    private val statelessTags = setOf("LinearLayout", "FrameLayout", "ImageView")

    private fun viewsWithIds(): List<Element> {
        val layout = Paths.get("src/main/res/layout/include_ai_classifier_section.xml")
        val document =
            Files.newInputStream(layout).use { input ->
                DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(input)
            }
        val nodes = document.getElementsByTagName("*")
        return (0 until nodes.length).map { nodes.item(it) as Element }.filter { it.hasAttribute("android:id") }
    }

    @Test
    fun test_the_prompt_box_does_not_save_its_text() {
        val prompt = viewsWithIds().single { it.getAttribute("android:id") == "@+id/ai_prompt_input" }

        assertEquals("EditText", prompt.tagName)
        assertEquals("false", prompt.getAttribute("android:saveEnabled"))
    }

    @Test
    fun test_no_view_in_the_shared_include_saves_state() {
        val stateful = viewsWithIds().filterNot { it.tagName in statelessTags }

        assertTrue(stateful.size >= 6)
        stateful.forEach {
            assertEquals("${it.getAttribute("android:id")} saves state", "false", it.getAttribute("android:saveEnabled"))
        }
    }
}
