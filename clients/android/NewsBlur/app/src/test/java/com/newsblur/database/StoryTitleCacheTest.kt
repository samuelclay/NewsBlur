package com.newsblur.database

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertSame
import org.junit.Test

class StoryTitleCacheTest {
    @Test
    fun reusesTheParsedCharSequenceWithoutFlatteningFormatting() {
        var parses = 0
        val cache = StoryTitleCache { parses++; StringBuilder(it) }
        val first = cache.get("<b>A title</b> &amp; more")

        assertSame(first, cache.get("<b>A title</b> &amp; more"))
        assertEquals(1, parses)
    }

    @Test
    fun changedHtmlAndExplicitResetInvalidateCachedTitles() {
        val cache = StoryTitleCache { StringBuilder(it) }
        val first = cache.get("<b>A title</b>")
        assertNotSame(first, cache.get("<i>A title</i>"))
        cache.clear()
        assertNotSame(first, cache.get("<b>A title</b>"))
    }

    @Test
    fun evictsTheLeastRecentlyUsedTitleByCharacterBudget() {
        val cache = StoryTitleCache(maxCharacters = 16) { StringBuilder(it) }
        val first = cache.get("one")
        val second = cache.get("two")
        assertSame(first, cache.get("one"))
        cache.get("tri")
        assertSame(first, cache.get("one"))
        assertNotSame(second, cache.get("two"))
    }

    @Test
    fun oversizedTitlesAreRenderedButNeverEvictTheWorkingSet() {
        val cache = StoryTitleCache(maxCharacters = 16) { StringBuilder(it) }
        val first = cache.get("one")
        val huge = cache.get("a very long story title")
        assertNotSame(huge, cache.get("a very long story title"))
        assertSame(first, cache.get("one"))
    }
}
