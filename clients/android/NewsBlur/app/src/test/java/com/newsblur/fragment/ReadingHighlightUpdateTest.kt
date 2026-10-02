package com.newsblur.fragment

import com.newsblur.domain.Story
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Test

class ReadingHighlightUpdateTest {
    @Test
    fun addingAndClearingHighlightsUpdatesTheExistingDocumentWithoutReloadingIt() {
        val highlights = linkedSetOf("old selection")
        val fragment = fragmentWithHighlights(highlights)

        deliverHighlights(fragment, listOf("old selection", "new selection"))
        assertEquals(setOf("old selection", "new selection"), highlights)
        deliverHighlights(fragment, emptyList())
        assertEquals(emptySet<String>(), highlights)

        verify(exactly = 2) { fragment["applyStoryHighlights"]() }
        verify(exactly = 0) { fragment["reloadStoryContent"]() }
        verify(exactly = 0) { fragment["setupWebviewInternal"](any<String>()) }
    }

    @Test
    fun theViewModelsSharedSetUpdateStillReachesTheJavascriptBridge() {
        // ReadingItemViewModel.kt can update the shared set before delivering its completion event.
        val highlights = linkedSetOf("already updated selection")
        val fragment = fragmentWithHighlights(highlights)

        deliverHighlights(fragment, highlights.toList())

        verify(exactly = 1) { fragment["applyStoryHighlights"]() }
        verify(exactly = 0) { fragment["reloadStoryContent"]() }
    }

    private fun fragmentWithHighlights(highlights: MutableSet<String>): ReadingItemFragment {
        val fragment = mockk<ReadingItemFragment>(relaxed = true)
        fragment.story = Story()
        every { fragment["handleStoryHighlightsUpdate"](any<List<String>>()) } answers { callOriginal() }
        ReadingItemFragment::class.java.getDeclaredField("storyHighlights").apply {
            isAccessible = true
            set(fragment, highlights)
        }
        return fragment
    }

    private fun deliverHighlights(
        fragment: ReadingItemFragment,
        highlights: List<String>,
    ) {
        ReadingItemFragment::class.java.getDeclaredMethod("handleStoryHighlightsUpdate", List::class.java).apply {
            isAccessible = true
            invoke(fragment, highlights)
        }
    }
}
