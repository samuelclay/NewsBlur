package com.newsblur.listen

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Test_ListenParagraphMatcher.kt checks how manifest paragraphs find their blocks in the rendered story. */
class Test_ListenParagraphMatcher {
    private fun paragraph(
        index: Int,
        text: String,
        kind: String = "text",
    ) = ListenParagraph(index = index, kind = kind, text = text)

    @Test
    fun test_normalize_collapses_whitespace() {
        assertEquals("One two three", ListenParagraphMatcher.normalize("  One\n\t two  three  "))
    }

    @Test
    fun test_matches_by_first_forty_characters_in_order() {
        val paragraphs =
            listOf(
                paragraph(0, "A Story Title", kind = ListenParagraph.KIND_TITLE),
                paragraph(
                    1,
                    "The first paragraph is long enough to be cut at forty characters, then more.",
                ),
                paragraph(2, "Second paragraph."),
                paragraph(3, "A heading"),
            )
        val blocks =
            listOf(
                "The first paragraph is long enough to be cut at forty characters, and differs after",
                "An advertisement nobody reads",
                "Second   paragraph.",
                "A heading",
            )
        assertEquals(
            mapOf(0 to 1, 2 to 2, 3 to 3),
            ListenParagraphMatcher.match(paragraphs, blocks),
        )
    }

    @Test
    fun test_title_is_left_to_the_native_header() {
        val paragraphs = listOf(paragraph(0, "Same text", kind = ListenParagraph.KIND_TITLE))
        assertTrue(ListenParagraphMatcher.match(paragraphs, listOf("Same text")).isEmpty())
    }

    @Test
    fun test_scanning_forward_never_reuses_earlier_blocks() {
        val paragraphs =
            listOf(
                paragraph(1, "Repeated line"),
                paragraph(2, "Repeated line"),
                paragraph(3, "Repeated line"),
            )
        val blocks = listOf("Repeated line", "Something else", "Repeated line")
        assertEquals(mapOf(0 to 1, 2 to 2), ListenParagraphMatcher.match(paragraphs, blocks))
    }

    @Test
    fun test_unmatched_paragraphs_are_skipped_without_losing_place() {
        val paragraphs =
            listOf(
                paragraph(1, "Missing from the page entirely"),
                paragraph(2, "Present on the page"),
            )
        val blocks = listOf("Present on the page")
        assertEquals(mapOf(0 to 2), ListenParagraphMatcher.match(paragraphs, blocks))
    }

    @Test
    fun test_punctuation_differences_still_match() {
        val paragraphs = listOf(paragraph(1, "“It’s done,” she said — and then she left the room."))
        val blocks = listOf("\"It's done,\" she said - and then she left the room.")
        assertEquals(mapOf(0 to 1), ListenParagraphMatcher.match(paragraphs, blocks))
    }

    @Test
    fun test_case_differences_still_match() {
        val paragraphs = listOf(paragraph(1, "BREAKING NEWS FROM THE CITY"))
        assertEquals(
            mapOf(0 to 1),
            ListenParagraphMatcher.match(paragraphs, listOf("Breaking news from the city")),
        )
    }

    @Test
    fun test_blocks_for_segment_paragraphs() {
        val map = mapOf(4 to 2, 1 to 1, 7 to 3)
        assertEquals(listOf(1, 4), ListenParagraphMatcher.blocksFor(listOf(1, 2), map))
        assertTrue(ListenParagraphMatcher.blocksFor(listOf(9), map).isEmpty())
    }
}
