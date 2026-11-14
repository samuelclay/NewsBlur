package com.newsblur.listen

import com.google.gson.JsonParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Test_ListenUpNextQueue.kt checks Up Next's ordering rules in ListenUpNext.kt, shared with the web media player:
 * Android shows and plays stories read aloud and podcast episodes, and leaves videos where the web put them.
 */
class Test_ListenUpNextQueue {
    private fun listen(hash: String) =
        ListenQueueItem(hash, ListenUpNextQueue.mediaUrl(hash), ListenUpNextQueue.MEDIA_TYPE_LISTEN, "Story $hash", "1", null)

    private fun podcast(hash: String) = ListenQueueItem(hash, "https://example.com/$hash.mp3", "audio", "Episode $hash", "2", null)

    private fun video(hash: String) = ListenQueueItem(hash, "https://example.com/$hash.mp4", "video", "Video $hash", "3", null)

    private val a = listen("1:a")
    private val b = listen("1:b")
    private val c = listen("1:c")
    private val episode = podcast("2:p")
    private val clip = video("3:v")

    @Test
    fun test_stories_and_podcasts_count_for_position_and_videos_do_not() {
        val queue = listOf(clip, episode, a, b)
        assertEquals(listOf(episode, a, b), ListenUpNextQueue.playableItems(queue))
        assertEquals(listOf(a, b), ListenUpNextQueue.listenItems(queue))
        assertEquals(1, ListenUpNextQueue.positionOf(queue, episode.entryId))
        assertEquals(2, ListenUpNextQueue.positionOf(queue, a.entryId))
        assertNull(ListenUpNextQueue.positionOf(queue, clip.entryId))
        // The + beside Listen only knows about stories read aloud.
        assertTrue(ListenUpNextQueue.isQueued(queue, "1:b"))
        assertFalse(ListenUpNextQueue.isQueued(queue, "2:p"))
        assertTrue(ListenUpNextQueue.containsEntry(queue, episode.entryId))
    }

    @Test
    fun test_next_plays_the_first_playable_entry_only_with_auto_play() {
        val queue = listOf(clip, episode, a)
        assertEquals(episode, ListenUpNextQueue.next(queue, autoPlayNext = true))
        assertNull(ListenUpNextQueue.next(queue, autoPlayNext = false))
        // A video queued on the web waits for the web.
        assertNull(ListenUpNextQueue.next(listOf(clip), autoPlayNext = true))
    }

    @Test
    fun test_a_story_and_its_own_episode_are_different_entries() {
        val sameStory = podcast("1:a")
        assertFalse(a.entryId == sameStory.entryId)
        val queue = listOf(a, sameStory)
        assertEquals(listOf(a), ListenUpNextQueue.withoutEntry(queue, sameStory.entryId))
        assertEquals(listOf(sameStory), ListenUpNextQueue.withoutEntry(queue, a.entryId))
    }

    @Test
    fun test_append_moves_an_existing_copy_to_the_end() {
        val queue = ListenUpNextQueue.appended(listOf(a, episode, b), a)
        assertEquals(listOf(episode, b, a), queue)
        assertEquals(3, ListenUpNextQueue.positionOf(queue, a.entryId))
    }

    @Test
    fun test_play_next_moves_an_existing_copy_to_the_front() {
        val queue = ListenUpNextQueue.prepended(listOf(a, clip, episode), episode)
        assertEquals(listOf(episode, a, clip), queue)
        assertEquals(1, ListenUpNextQueue.positionOf(queue, episode.entryId))
    }

    @Test
    fun test_remove_leaves_other_media_alone() {
        assertEquals(listOf(episode, b), ListenUpNextQueue.without(listOf(a, episode, b), "1:a"))
        // A podcast sharing a story hash isn't a Listen entry, so it stays.
        val sameHash = podcast("1:a")
        assertEquals(listOf(sameHash), ListenUpNextQueue.without(listOf(sameHash, a), "1:a"))
    }

    @Test
    fun test_reorder_keeps_videos_in_their_slots() {
        val queue = listOf(a, clip, episode, b)
        assertEquals(
            listOf(b, clip, a, episode),
            ListenUpNextQueue.withPlayableOrder(queue, listOf(b.entryId, a.entryId, episode.entryId)),
        )
        // Playable entries the new order leaves out follow the ones it names, in their old order.
        assertEquals(listOf(b, clip, a, episode), ListenUpNextQueue.withPlayableOrder(queue, listOf(b.entryId)))
    }

    @Test
    fun test_move_counts_positions_as_up_next_shows_them() {
        val queue = listOf(clip, episode, a, b)
        assertEquals(listOf(clip, a, b, episode), ListenUpNextQueue.moved(queue, from = 0, to = 2))
        assertEquals(listOf(clip, b, episode, a), ListenUpNextQueue.moved(queue, from = 2, to = 0))
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
                     ],
                     "current_story_hash": "2:p", "current_media_url": "https://example.com/2:p.mp3",
                     "current_media_type": "audio", "current_media_title": "Episode 2:p", "current_feed_id": 2,
                     "current_image_url": "", "current_position": 754.2, "current_duration": 3600,
                     "current_playback_rate": 1.5, "skip_back_seconds": 10, "skip_forward_seconds": 60,
                     "auto_play_next": false, "remember_position": true, "resume_on_load": true
                    }, "result": "ok"}
                    """.trimIndent(),
                ).asJsonObject
        val state = ListenUpNextQueue.parseResponse(response)!!
        assertEquals(listOf(a.copy(imageUrl = null), episode), state.queue)
        assertEquals(listOf(ListenHistoryEntry(b.copy(feedId = null), 12.5, 0.0)), state.history)
        assertEquals(ListenCurrentMedia("2:p", episode.mediaUrl, "audio", 754.2, 3600.0, "Episode 2:p", "2", null), state.current)
        assertEquals(ListenMediaSettings(skipBackSeconds = 10, skipForwardSeconds = 60, autoPlayNext = false), state.settings)
        assertEquals(1.5, state.mediaSpeed!!, 0.0)
    }

    @Test
    fun test_missing_or_zero_settings_use_the_web_defaults() {
        val response =
            JsonParser
                .parseString(
                    """{"playback_state": {"queue": [], "history": [], "current_media_url": "",
                        "skip_back_seconds": 0, "current_playback_rate": 0}}""",
                ).asJsonObject
        val state = ListenUpNextQueue.parseResponse(response)!!
        assertNull(state.current)
        assertNull(state.mediaSpeed)
        assertEquals(ListenMediaSettings(), state.settings)
        assertEquals(15_000L, state.settings.skipBackMs)
        assertEquals(30_000L, state.settings.skipForwardMs)
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
