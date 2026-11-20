package com.newsblur.database

import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListUpdateCallback
import com.newsblur.database.StoryViewAdapter.DisplayItem
import com.newsblur.database.StoryViewAdapter.DisplayItemDiffer
import com.newsblur.domain.Story
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class StoryViewAdapterDiffTest {
    @Test
    fun markingReadDispatchesAnInPlacePayloadInsteadOfReplacingTheCell() {
        val changes = Changes()
        val before = listOf(row(story()), row(story(hash = "2:story")))
        val after = listOf(row(story(read = true)), row(story(hash = "2:story")))

        DiffUtil.calculateDiff(DisplayItemDiffer(before, after), false).dispatchUpdatesTo(changes)

        assertEquals(0, changes.structuralUpdates)
        assertEquals(listOf(0), changes.changedPositions)
        assertNotNull("Read status must not reload an unchanged title or thumbnail", changes.payloads.single())
    }

    @Test
    fun editedHtmlTitleAndThumbnailMustInvalidateTheCellEvenWhenReadStateIsUnchanged() {
        val before = row(story())
        val edited = row(story().apply { title = "Updated <em>title</em>"; thumbnailUrl = "https://example.com/new.jpg" })
        val diff = DisplayItemDiffer(listOf(before), listOf(edited))

        assertTrue(diff.areItemsTheSame(0, 0))
        assertFalse("StoryViewAdapter must redraw edited content", diff.areContentsTheSame(0, 0))
        assertNull("Content changes require a complete bind", diff.getChangePayload(0, 0))
    }

    @Test
    fun aLocallyMutatedStoryStillProducesAReadChange() {
        val story = story()
        val before = row(story)
        story.read = true
        val after = row(story)
        val diff = DisplayItemDiffer(listOf(before), listOf(after))

        assertFalse("The previous display row must retain its unread snapshot", diff.areContentsTheSame(0, 0))
        assertNotNull(diff.getChangePayload(0, 0))
    }

    @Test
    fun markingReadWhileEditingContentRequiresAFullBind() {
        val before = row(story())
        val after = row(story(read = true).apply { shortContent = "Updated preview" })
        val diff = DisplayItemDiffer(listOf(before), listOf(after))

        assertFalse(diff.areContentsTheSame(0, 0))
        assertNull(diff.getChangePayload(0, 0))
    }

    @Test
    fun unchangedRowsAndPagingKeepTheirIdentity() {
        val changes = Changes()
        val before = listOf(row(story()))
        val after = listOf(row(story()), row(story(hash = "2:story")))

        DiffUtil.calculateDiff(DisplayItemDiffer(before, after), false).dispatchUpdatesTo(changes)

        assertTrue(changes.changedPositions.isEmpty())
        assertEquals(1, changes.structuralUpdates)
    }

    @Test
    fun matchedStoryReadChangesAlsoPreserveTheirThumbnail() {
        val story = Story.ClusterStory().apply {
            storyHash = "2:matched"
            feedId = "2"
            title = "A matched title"
        }
        val before = DisplayItem.ClusterRow(story, 0, "1:story")
        story.read = true
        val after = DisplayItem.ClusterRow(story, 0, "1:story")
        val diff = DisplayItemDiffer(listOf(before), listOf(after))

        assertFalse(diff.areContentsTheSame(0, 0))
        assertNotNull(diff.getChangePayload(0, 0))
    }

    private fun row(story: Story) = DisplayItem.StoryRow(story, 0)

    private fun story(hash: String = "1:story", read: Boolean = false) =
        Story().apply {
            storyHash = hash
            feedId = hash.substringBefore(':')
            id = hash
            this.read = read
            title = "A <b>formatted</b> title"
            authors = "Sam"
            shortContent = "The story preview"
            thumbnailUrl = "https://example.com/preview.jpg"
            sharedUserIds = emptyArray()
        }

    private class Changes : ListUpdateCallback {
        var structuralUpdates = 0
        val changedPositions = mutableListOf<Int>()
        val payloads = mutableListOf<Any?>()

        override fun onInserted(position: Int, count: Int) { structuralUpdates += count }
        override fun onRemoved(position: Int, count: Int) { structuralUpdates += count }
        override fun onMoved(fromPosition: Int, toPosition: Int) { structuralUpdates++ }
        override fun onChanged(position: Int, count: Int, payload: Any?) {
            changedPositions.addAll(position until position + count)
            payloads.add(payload)
        }
    }
}
