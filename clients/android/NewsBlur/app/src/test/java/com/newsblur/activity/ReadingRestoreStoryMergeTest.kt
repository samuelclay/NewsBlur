package com.newsblur.activity

import com.newsblur.domain.Story
import com.newsblur.util.StoryOrder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test

class ReadingRestoreStoryMergeTest {
    @Test
    fun mergesMissingRestoredStoryIntoNewestSortedStories() {
        val olderStory = story(hash = "older", timestamp = 100L)
        val newerStory = story(hash = "newer", timestamp = 300L)
        val restoredStory = story(hash = "restored", timestamp = 200L)

        val mergedStories =
            mergeRestoredStoryIntoStories(
                stories = listOf(newerStory, olderStory),
                targetStoryHash = restoredStory.storyHash,
                restoredStory = restoredStory,
                storyOrder = StoryOrder.NEWEST,
            )

        assertEquals(listOf(newerStory, restoredStory, olderStory), mergedStories)
    }

    @Test
    fun mergesMissingRestoredStoryIntoOldestSortedStories() {
        val olderStory = story(hash = "older", timestamp = 100L)
        val newerStory = story(hash = "newer", timestamp = 300L)
        val restoredStory = story(hash = "restored", timestamp = 200L)

        val mergedStories =
            mergeRestoredStoryIntoStories(
                stories = listOf(olderStory, newerStory),
                targetStoryHash = restoredStory.storyHash,
                restoredStory = restoredStory,
                storyOrder = StoryOrder.OLDEST,
            )

        assertEquals(listOf(olderStory, restoredStory, newerStory), mergedStories)
    }

    @Test
    fun doesNotDuplicateStoryAlreadyPresentInBatch() {
        val presentStory = story(hash = "restored", timestamp = 200L)
        val stories = listOf(story(hash = "newer", timestamp = 300L), presentStory)

        val mergedStories =
            mergeRestoredStoryIntoStories(
                stories = stories,
                targetStoryHash = presentStory.storyHash,
                restoredStory = presentStory,
                storyOrder = StoryOrder.NEWEST,
            )

        assertSame(stories, mergedStories)
    }

    @Test
    fun ignoresRestoredStoryWhenHashDoesNotMatchRequestedTarget() {
        val stories = listOf(story(hash = "newer", timestamp = 300L))
        val restoredStory = story(hash = "restored", timestamp = 200L)

        val mergedStories =
            mergeRestoredStoryIntoStories(
                stories = stories,
                targetStoryHash = "other",
                restoredStory = restoredStory,
                storyOrder = StoryOrder.NEWEST,
            )

        assertSame(stories, mergedStories)
    }

    @Test
    fun keepsRestoredStoryPinnedAfterInitialPagerRestore() {
        val restoredStory = story(hash = "restored", timestamp = 200L)

        val state = readingStateAfterPagerTargetFound(restoredStory)

        assertNull(state.storyHash)
        assertSame(restoredStory, state.restoredCurrentStory)
        assertFalse(state.isRestoringState)
    }

    @Test
    fun pinnedRestoredStoryCanMergeAfterTargetHashWasCleared() {
        val restoredStory = story(hash = "restored", timestamp = 200L)
        val state = readingStateAfterPagerTargetFound(restoredStory)

        val mergedStories =
            mergeRestoredStoryIntoStories(
                stories = emptyList(),
                targetStoryHash = state.restoredCurrentStory?.storyHash,
                restoredStory = state.restoredCurrentStory,
                storyOrder = StoryOrder.NEWEST,
            )

        assertEquals(listOf(restoredStory), mergedStories)
    }

    private fun story(
        hash: String,
        timestamp: Long,
    ): Story =
        Story().apply {
            storyHash = hash
            feedId = "1"
            this.timestamp = timestamp
        }
}
