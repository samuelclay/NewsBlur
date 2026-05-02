package com.newsblur.activity

import com.newsblur.domain.Story
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertNull
import org.junit.Test

class ReadingConfigChangeRestoreTest {
    @Test
    fun noStoryHashDoesNotCreateRestoreState() {
        assertNull(createReadingConfigChangeRestore(null, 0.42f))
    }

    @Test
    fun restoreStateDefaultsMissingScrollPositionToTop() {
        assertEquals(
            ReadingConfigChangeRestore("story-hash", 0f),
            createReadingConfigChangeRestore("story-hash", null),
        )
    }

    @Test
    fun restoreStateKeepsStoryHashAndRelativeScrollPosition() {
        assertEquals(
            ReadingConfigChangeRestore("story-hash", 0.42f),
            createReadingConfigChangeRestore("story-hash", 0.42f),
        )
    }

    @Test
    fun restoreStateKeepsBundleSizedCopyOfMatchingCurrentStory() {
        val story =
            Story().apply {
                storyHash = "story-hash"
                title = "Current unread story"
                content = "large body omitted from restore state"
            }

        val restore = createReadingConfigChangeRestore("story-hash", 0.42f, story)

        assertEquals("story-hash", restore?.story?.storyHash)
        assertEquals("Current unread story", restore?.story?.title)
        assertNull(restore?.story?.content)
        assertNotSame(story, restore?.story)
    }

    @Test
    fun restoreStateIgnoresStoryWithDifferentHash() {
        val story =
            Story().apply {
                storyHash = "other-story"
                title = "Wrong story"
            }

        val restore = createReadingConfigChangeRestore("story-hash", 0.42f, story)

        assertNull(restore?.story)
    }

    @Test
    fun restoreStatePrefersVisibleStoryWhenPagerDataShiftedAfterMarkRead() {
        val visibleStory =
            Story().apply {
                storyHash = "visible-read-story"
                title = "Story still on screen"
                read = true
            }
        val pagerStory =
            Story().apply {
                storyHash = "next-unread-story"
                title = "Next story in shifted adapter"
                read = false
            }

        val restore =
            createReadingConfigChangeRestore(
                visibleStory = visibleStory,
                pagerStory = pagerStory,
                fallbackStoryHash = null,
                scrollPosRel = 0.42f,
            )

        assertEquals("visible-read-story", restore?.storyHash)
        assertEquals("visible-read-story", restore?.story?.storyHash)
        assertEquals(true, restore?.story?.read)
    }
}
