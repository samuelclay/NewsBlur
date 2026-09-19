package com.newsblur.database

import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import com.google.gson.Gson
import com.newsblur.domain.Story
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.*
import org.junit.Test

class ClusterReadStoreNormalizeTest {
    private val db = mockk<SQLiteDatabase>(relaxed = true)
    private var receipt: Boolean? = null
    private var stored: Boolean? = null
    private var embedded = emptyMap<String, Array<Story.ClusterStory>>()
    private val store = ClusterReadStore(db)

    init {
        every { db.query(any<String>(), any(), any(), any(), any(), any(), any()) } answers {
            val isReceipt = firstArg<String>() == ClusterReadStore.READ_STATE
            val state = if (isReceipt) receipt else stored
            mockk<Cursor>(relaxed = true).also { cursor ->
                every { cursor.moveToFirst() } returns (state != null)
                every { cursor.getInt(any()) } answers { if (state == true) 1 else 0 }
                every { cursor.getString(any()) } answers { if (firstArg<Int>() == 0) "1" else "" }
            }
        }
        every { db.rawQuery(any(), any()) } answers {
            val parents = embedded.toList()
            var position = -1
            mockk<Cursor>(relaxed = true).also { cursor ->
                every { cursor.moveToNext() } answers { ++position < parents.size }
                every { cursor.getString(any()) } answers {
                    if (firstArg<Int>() == 0) parents[position].first else Gson().toJson(parents[position].second)
                }
            }
        }
    }

    @Test fun hashLookupCannotReviveReadStoryAfterReceiptWasAcknowledged() {
        stored = true
        val story = Story().apply { storyHash = "1:parent"; read = false }
        store.normalizeStory(story, false)
        assertTrue(story.read)
    }

    @Test fun fullFeedUnreadRemainsAuthoritativeWithoutPendingLocalReceipt() {
        stored = true
        val story = Story().apply { storyHash = "1:parent"; read = false }
        store.normalizeStory(story, true)
        assertFalse(story.read)
    }

    @Test fun staleStandaloneAndEmbeddedMetadataCannotDefeatLocalReceipt() {
        receipt = true
        val child = Story.ClusterStory().apply { storyHash = "2:child"; read = false }
        val story = Story().apply { storyHash = "1:parent"; read = false; clusterStories = arrayOf(child) }
        store.normalizeStory(story, false)
        assertTrue(story.read)
        assertTrue(story.clusterStories[0].read)
        assertFalse(child.read)
        verify(exactly = 0) { db.delete(any(), any(), any()) }
    }

    @Test fun serverAcknowledgementRetiresReceiptForFutureRemoteUnreadChanges() {
        receipt = true
        val story = Story().apply { storyHash = "1:parent"; read = true }
        store.normalizeStory(story, true)
        verify { db.delete(ClusterReadStore.READ_STATE, "story_hash = ?", arrayOf("1:parent")) }
    }

    @Test fun hashPlaceholderCannotAcknowledgeAnExplicitUnreadReceipt() {
        receipt = false
        val story = Story().apply { storyHash = "1:parent"; read = false }

        store.normalizeStory(story, false)

        assertFalse(story.read)
        verify(exactly = 0) { db.delete(ClusterReadStore.READ_STATE, any(), any()) }
    }

    @Test fun hashLookupPreservesReadStateKnownOnlyInParentMetadata() {
        embedded = mapOf("1:parent" to arrayOf(Story.ClusterStory().apply { storyHash = "2:child"; read = true }))
        val story = Story().apply { storyHash = "2:child"; read = false }

        store.normalizeStory(story, false)

        assertTrue(story.read)
    }

    @Test fun conflictingParentMetadataKeepsKnownReadStateDuringHashLookup() {
        embedded = mapOf(
            "1:parent" to arrayOf(Story.ClusterStory().apply { storyHash = "2:child"; read = false }),
            "3:parent" to arrayOf(Story.ClusterStory().apply { storyHash = "2:child"; read = true }),
        )
        val story = Story().apply { storyHash = "2:child"; read = false }

        store.normalizeStory(story, false)

        assertTrue(story.read)
    }

    @Test fun explicitUnreadAndAuthoritativeFeedResponsesOutrankEmbeddedReadMetadata() {
        embedded = mapOf("1:parent" to arrayOf(Story.ClusterStory().apply { storyHash = "2:child"; read = true }))
        val fromFeed = Story().apply { storyHash = "2:child"; read = false }
        store.normalizeStory(fromFeed, true)
        assertFalse(fromFeed.read)

        stored = false
        val fromHash = Story().apply { storyHash = "2:child"; read = false }
        store.normalizeStory(fromHash, false)
        assertFalse(fromHash.read)

        stored = null
        receipt = false
        store.normalizeStory(fromHash, false)
        assertFalse(fromHash.read)
        verify(exactly = 0) { db.rawQuery(any(), any()) }
    }
}
