package com.newsblur.listen

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Test_ListenMediaResume.kt checks where a podcast episode starts (ListenMedia.kt): at the position the web or iOS
 * saved for it, so one paused on the web resumes on Android, and at the top whenever that position doesn't apply.
 */
class Test_ListenMediaResume {
    private val storyHash = "7:ep1"
    private val url = "https://cdn.example.com/show/ep1.mp3"

    private fun current(
        mediaUrl: String = url,
        storyHash: String = this.storyHash,
        mediaType: String = "audio",
        position: Double = 754.2,
        duration: Double = 3600.0,
    ) = ListenCurrentMedia(storyHash, mediaUrl, mediaType, position, duration)

    private fun history(
        mediaUrl: String,
        storyHash: String,
        position: Double,
        duration: Double = 3600.0,
    ) = ListenHistoryEntry(ListenQueueItem(storyHash, mediaUrl, "audio", "Episode", "7", null), position, duration)

    private fun state(
        current: ListenCurrentMedia? = null,
        history: List<ListenHistoryEntry> = emptyList(),
        rememberPosition: Boolean = true,
    ) = ListenPlaybackState(
        current = current,
        history = history,
        settings = ListenMediaSettings(rememberPosition = rememberPosition),
    )

    @Test
    fun test_resumes_where_the_web_left_this_episode() {
        assertEquals(754_200L, ListenMediaResume.startPositionMs(state(current()), storyHash, url))
    }

    @Test
    fun test_falls_back_to_the_story_when_the_file_url_changed() {
        val moved = current(mediaUrl = "https://other-cdn.example.com/ep1.mp3?tracking=2")
        assertEquals(754_200L, ListenMediaResume.startPositionMs(state(moved), storyHash, url))
    }

    @Test
    fun test_another_current_item_starts_from_the_top() {
        val other = current(mediaUrl = "https://cdn.example.com/show/ep2.mp3", storyHash = "7:ep2")
        assertEquals(0L, ListenMediaResume.startPositionMs(state(other), storyHash, url))
        assertEquals(0L, ListenMediaResume.startPositionMs(state(current = null), storyHash, url))
        assertEquals(0L, ListenMediaResume.startPositionMs(null, storyHash, url))
    }

    @Test
    fun test_remember_position_off_always_starts_from_the_top() {
        assertEquals(0L, ListenMediaResume.startPositionMs(state(current(), rememberPosition = false), storyHash, url))
        val played = listOf(history(url, storyHash, 120.0))
        assertEquals(0L, ListenMediaResume.startPositionMs(state(history = played, rememberPosition = false), storyHash, url))
    }

    @Test
    fun test_the_same_story_read_aloud_is_not_this_episode() {
        // Listen's position is in its own synthesized audio, nowhere near the same moment in the podcast file.
        val listening = current(mediaUrl = ListenUpNextQueue.mediaUrl(storyHash), mediaType = "listen")
        assertEquals(0L, ListenMediaResume.startPositionMs(state(listening), storyHash, url))
        assertFalse(ListenMediaResume.isSameMedia(storyHash, ListenUpNextQueue.mediaUrl(storyHash), "listen", storyHash, url))
        assertTrue(ListenMediaResume.isSameMedia(storyHash, url, "audio", "9:other", url))
        // The story's video is other media too: the story_hash fallback needs the same media type.
        val video = current(mediaUrl = "https://cdn.example.com/show/ep1.mp4", mediaType = "video")
        assertEquals(0L, ListenMediaResume.startPositionMs(state(video), storyHash, url))
    }

    @Test
    fun test_a_finished_episode_plays_again_from_the_top() {
        assertEquals(0L, ListenMediaResume.startPositionMs(state(current(position = 3598.0)), storyHash, url))
        assertEquals(0L, ListenMediaResume.startPositionMs(state(current(position = 3600.0)), storyHash, url))
        // Without a known length there's no end to compare against.
        assertEquals(3_598_000L, ListenMediaResume.startPositionMs(state(current(position = 3598.0, duration = 0.0)), storyHash, url))
    }

    @Test
    fun test_history_resumes_an_episode_that_is_no_longer_current() {
        val other = current(mediaUrl = "https://cdn.example.com/show/ep2.mp3", storyHash = "7:ep2")
        val played =
            listOf(
                history("https://cdn.example.com/show/ep9.mp3", storyHash, 50.0),
                history(url, storyHash, 1200.5),
            )
        // The exact file wins over another of the story's files listed first.
        assertEquals(1_200_500L, ListenMediaResume.startPositionMs(state(other, played), storyHash, url))
        // The server's current item is fresher than History when both name the episode.
        assertEquals(754_200L, ListenMediaResume.startPositionMs(state(current(), played), storyHash, url))
    }

    @Test
    fun test_plain_http_files_stream_over_https() {
        assertEquals("https://feeds.example.com/ep.mp3", ListenMedia("http://feeds.example.com/ep.mp3").streamUrl)
        assertEquals("https://feeds.example.com/ep.mp3", ListenMedia("https://feeds.example.com/ep.mp3").streamUrl)
        // The original address stays the episode's identity on the server.
        assertEquals("http://feeds.example.com/ep.mp3", ListenMedia("http://feeds.example.com/ep.mp3").url)
    }
}
