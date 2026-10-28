package com.newsblur.listen

import com.google.gson.JsonParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/** Test_ListenUpNextQueue.kt checks Up Next's ordering rules in ListenUpNext.kt, shared with the web media player. */
class Test_ListenUpNextQueue {
    private fun listen(hash: String) =
        ListenQueueItem(hash, ListenUpNextQueue.mediaUrl(hash), ListenUpNextQueue.MEDIA_TYPE_LISTEN, "Story $hash", "1", null)

    private fun podcast(hash: String) = ListenQueueItem(hash, "https://example.com/$hash.mp3", "audio", "Episode $hash", "2", null)

    private val a = listen("1:a")
    private val b = listen("1:b")
    private val c = listen("1:c")
    private val episode = podcast("2:p")

    @Test
    fun test_only_listen_entries_count_for_position() {
        val queue = listOf(episode, a, b)
        assertEquals(listOf(a, b), ListenUpNextQueue.listenItems(queue))
        assertEquals(1, ListenUpNextQueue.positionOf(queue, "1:a"))
        assertEquals(2, ListenUpNextQueue.positionOf(queue, "1:b"))
        assertNull(ListenUpNextQueue.positionOf(queue, "2:p"))
        assertTrue(ListenUpNextQueue.isQueued(queue, "1:b"))
        assertFalse(ListenUpNextQueue.isQueued(queue, "2:p"))
        assertEquals(a, ListenUpNextQueue.next(queue))
    }

    @Test
    fun test_append_moves_an_existing_copy_to_the_end() {
        val queue = ListenUpNextQueue.appended(listOf(a, episode, b), a)
        assertEquals(listOf(episode, b, a), queue)
        assertEquals(2, ListenUpNextQueue.positionOf(queue, "1:a"))
    }

    @Test
    fun test_remove_leaves_other_media_alone() {
        assertEquals(listOf(episode, b), ListenUpNextQueue.without(listOf(a, episode, b), "1:a"))
        // A podcast sharing a story hash isn't a Listen entry, so it stays.
        val sameHash = podcast("1:a")
        assertEquals(listOf(sameHash), ListenUpNextQueue.without(listOf(sameHash, a), "1:a"))
    }

    @Test
    fun test_reorder_keeps_other_media_in_their_slots() {
        val queue = listOf(a, episode, b, c)
        assertEquals(listOf(c, episode, a, b), ListenUpNextQueue.withListenOrder(queue, listOf("1:c", "1:a", "1:b")))
        // Listen entries the new order leaves out follow the ones it names, in their old order.
        assertEquals(listOf(b, episode, a, c), ListenUpNextQueue.withListenOrder(queue, listOf("1:b")))
    }

    @Test
    fun test_move_counts_positions_as_up_next_shows_them() {
        val queue = listOf(episode, a, b, c)
        assertEquals(listOf(episode, b, c, a), ListenUpNextQueue.moved(queue, from = 0, to = 2))
        assertEquals(listOf(episode, c, a, b), ListenUpNextQueue.moved(queue, from = 2, to = 0))
        assertSame(queue, ListenUpNextQueue.moved(queue, from = 1, to = 1))
        assertSame(queue, ListenUpNextQueue.moved(queue, from = 0, to = 5))
    }

    @Test
    fun test_reorder_payload_sends_the_full_queue() {
        val payload = ListenUpNextQueue.reorderPayload(listOf(b, episode, a))
        assertEquals(
            listOf(
                mapOf("story_hash" to "1:b", "media_url" to "/listen/story/1:b"),
                mapOf("story_hash" to "2:p", "media_url" to "https://example.com/2:p.mp3"),
                mapOf("story_hash" to "1:a", "media_url" to "/listen/story/1:a"),
            ),
            payload,
        )
    }

    @Test
    fun test_parse_playback_state() {
        val response =
            JsonParser
                .parseString(
                    """
                    {"playback_state": {"queue": [
                        {"story_hash": "1:a", "media_url": "/listen/story/1:a", "media_type": "listen",
                         "media_title": "Story 1:a", "feed_id": 1, "image_url": ""},
                        {"story_hash": "2:p", "media_url": "https://example.com/2:p.mp3", "media_type": "audio",
                         "media_title": "Episode 2:p", "feed_id": "2", "image_url": null},
                        {"media_title": "No identity"}
                     ], "history": [
                        {"story_hash": "1:b", "media_url": "/listen/story/1:b", "media_type": "listen", "media_title": "Story 1:b",
                         "feed_id": 0, "position": 12.5}
                     ]}, "result": "ok"}
                    """.trimIndent(),
                ).asJsonObject
        val state = ListenUpNextQueue.parseResponse(response)!!
        assertEquals(listOf(a.copy(imageUrl = null), episode), state.queue)
        assertEquals(listOf(b.copy(feedId = null)), state.history)
    }

    @Test
    fun test_parse_empty_and_broken_responses() {
        val empty = JsonParser.parseString("""{"playback_state": null}""").asJsonObject
        assertEquals(ListenPlaybackState(), ListenUpNextQueue.parseResponse(empty))
        val unrelated = JsonParser.parseString("""{"result": "error"}""").asJsonObject
        assertNull(ListenUpNextQueue.parseResponse(unrelated))
        assertNull(ListenUpNextQueue.parseResponse(null))
    }
}
