package com.newsblur.listen

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Test_ListenMediaHandoff.kt checks how a story read aloud and a podcast episode share Listen's player
 * (ListenManager.kt): a story and its own episode are different entries, so starting one stops the other and sends it
 * to History; the story's Listen button only follows the story read aloud; and next plays Up Next in order.
 */
class Test_ListenMediaHandoff {
    private val url = "https://cdn.example.com/ep1.mp3"

    private fun story(
        hash: String,
        media: ListenMedia? = null,
    ) = ListenStory(hash, "Story $hash", hash.substringBefore(':'), "Feed", null, null, null, null, media)

    private val readAloud = story("7:ep1")
    private val episode = story("7:ep1", ListenMedia(url))

    @Test
    fun test_a_story_and_its_episode_are_different_entries() {
        // ListenManager.kt's startStory sends the previous entry to History whenever the entryId changes.
        assertNotEquals(readAloud.entryId, episode.entryId)
        assertEquals(ListenUpNextQueue.entryId("7:ep1", ListenUpNextQueue.mediaUrl("7:ep1")), readAloud.entryId)
        assertEquals(ListenUpNextQueue.entryId("7:ep1", url), episode.entryId)
    }

    @Test
    fun test_the_listen_button_follows_only_the_story_read_aloud() {
        val playingEpisode = ListenUiState(story = episode, phase = ListenPhase.READY, playWhenReady = true)
        // Tapping Listen while the episode plays starts reading the story aloud instead of pausing the episode.
        assertFalse(playingEpisode.isStory("7:ep1"))
        assertTrue(playingEpisode.isMedia)
        assertTrue(playingEpisode.isMediaLoaded(url))
        assertFalse(playingEpisode.isMediaLoaded("https://cdn.example.com/ep2.mp3"))

        val reading = ListenUiState(story = readAloud, phase = ListenPhase.READY, playWhenReady = true)
        assertTrue(reading.isStory("7:ep1"))
        assertFalse(reading.isMedia)
        assertFalse(reading.isMediaLoaded(url))
    }

    @Test
    fun test_next_plays_up_next_in_order_whatever_it_is() {
        val queuedEpisode = story("9:ep", ListenMedia("https://cdn.example.com/9.mp3"))
        val queuedStory = story("8:s")
        val state = ListenUiState(story = readAloud, queued = listOf(queuedEpisode, queuedStory))
        assertEquals(queuedEpisode, state.nextStory)
        // The story's own episode queued behind it isn't the entry playing, so it can play next.
        val ownEpisode = ListenUiState(story = readAloud, queued = listOf(episode))
        assertEquals(episode, ownEpisode.nextStory)
        assertNull(ListenUiState(story = episode, queued = listOf(episode)).nextStory)
    }

    @Test
    fun test_the_plus_beside_listen_ignores_a_queued_episode() {
        val state = ListenUiState(story = story("1:x"), queued = listOf(episode))
        assertFalse(state.isQueued("7:ep1"))
        assertTrue(ListenUiState(story = story("1:x"), queued = listOf(readAloud)).isQueued("7:ep1"))
    }

    @Test
    fun test_skip_intervals_default_to_the_web_players() {
        val state = ListenUiState()
        assertEquals(15, state.skipBackSeconds)
        assertEquals(30, state.skipForwardSeconds)
    }
}
