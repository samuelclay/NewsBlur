package com.newsblur.listen

import com.newsblur.network.ListenApi
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.coVerifyOrder
import io.mockk.mockk
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Test_ListenMediaSync.kt checks how ListenMediaSync.kt keeps the web media player's state in step with a podcast
 * episode: saved as it starts and pauses, its position sent at most every ten seconds while it plays, History when
 * it stops or finishes, and the skip intervals and podcast rate taken from the server.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class Test_ListenMediaSync {
    private val api = mockk<ListenApi>()
    private var now = 1_000_000L
    private val episode = ListenQueueItem("7:ep1", "https://cdn.example.com/ep1.mp3", "audio", "Episode 1", "7", null)

    private fun TestScope.sync(): ListenMediaSync {
        coEvery { api.savePlaybackState(any(), any(), any(), any(), any()) } returns ListenPlaybackState()
        coEvery { api.syncPlaybackPosition(any(), any(), any(), any(), any()) } returns true
        coEvery { api.addToHistory(any(), any(), any()) } returns true
        return ListenMediaSync(api, backgroundScope) { now }
    }

    @Test
    fun test_starting_saves_the_episode_as_current_and_playing() =
        runTest {
            val sync = sync()
            sync.started(episode, positionMs = 754_200L, durationMs = 0L)
            runCurrent()
            coVerify(exactly = 1) { api.savePlaybackState(episode, 754.2, 0.0, 1.0, true) }
        }

    @Test
    fun test_position_goes_out_at_most_every_ten_seconds_while_playing() =
        runTest {
            val sync = sync()
            sync.started(episode, positionMs = 0L, durationMs = 0L)
            // Ticks every 200ms for just under ten seconds send nothing more.
            repeat(49) {
                now += 200L
                sync.playing(episode, positionMs = (it + 1) * 200L, durationMs = 3_600_000L)
            }
            runCurrent()
            coVerify(exactly = 0) { api.syncPlaybackPosition(any(), any(), any(), any(), any()) }
            now += 200L
            sync.playing(episode, positionMs = 10_000L, durationMs = 3_600_000L)
            now += 200L
            sync.playing(episode, positionMs = 10_200L, durationMs = 3_600_000L)
            runCurrent()
            coVerify(exactly = 1) { api.syncPlaybackPosition(episode.mediaUrl, 10.0, 3600.0, 1.0, true) }
        }

    @Test
    fun test_pausing_saves_right_away_and_restarts_the_interval() =
        runTest {
            val sync = sync()
            sync.started(episode, positionMs = 0L, durationMs = 0L)
            now += 3_000L
            sync.paused(episode, positionMs = 3_000L, durationMs = 3_600_000L)
            runCurrent()
            coVerifyOrder {
                api.savePlaybackState(episode, 0.0, 0.0, 1.0, true)
                api.savePlaybackState(episode, 3.0, 3600.0, 1.0, false)
            }
            // Playing again right after the pause waits a full interval before the next position.
            now += 5_000L
            sync.playing(episode, positionMs = 3_500L, durationMs = 3_600_000L)
            runCurrent()
            coVerify(exactly = 0) { api.syncPlaybackPosition(any(), any(), any(), any(), any()) }
        }

    @Test
    fun test_backgrounding_saves_whatever_the_interval() =
        runTest {
            val sync = sync()
            sync.started(episode, positionMs = 0L, durationMs = 0L)
            now += 1_000L
            sync.saveNow(episode, positionMs = 1_000L, durationMs = 3_600_000L, isPlaying = true)
            runCurrent()
            coVerify(exactly = 1) { api.savePlaybackState(episode, 1.0, 3600.0, 1.0, true) }
        }

    @Test
    fun test_stopping_saves_the_place_then_records_history() =
        runTest {
            val sync = sync()
            sync.stopped(episode, positionMs = 61_500L, durationMs = 3_600_000L)
            runCurrent()
            coVerifyOrder {
                api.savePlaybackState(episode, 61.5, 3600.0, 1.0, false)
                api.addToHistory(episode, 61.5, 3600.0)
            }
        }

    @Test
    fun test_finishing_records_the_end_of_the_episode() =
        runTest {
            val sync = sync()
            sync.finished(episode, durationMs = 3_600_000L)
            runCurrent()
            coVerify { api.savePlaybackState(episode, 3600.0, 3600.0, 1.0, false) }
            coVerify { api.addToHistory(episode, 3600.0, 3600.0) }
        }

    @Test
    fun test_skip_intervals_and_podcast_rate_come_from_the_server() =
        runTest {
            val sync = sync()
            assertEquals(15_000L, sync.settings.skipBackMs)
            assertEquals(30_000L, sync.settings.skipForwardMs)
            sync.applyState(
                ListenPlaybackState(
                    settings = ListenMediaSettings(skipBackSeconds = 10, skipForwardSeconds = 60, autoPlayNext = false),
                    mediaSpeed = 1.5,
                ),
            )
            assertEquals(10_000L, sync.settings.skipBackMs)
            assertEquals(60_000L, sync.settings.skipForwardMs)
            assertEquals(false, sync.settings.autoPlayNext)
            sync.started(episode, positionMs = 0L, durationMs = 0L)
            runCurrent()
            coVerify { api.savePlaybackState(episode, 0.0, 0.0, 1.5, true) }
        }

    @Test
    fun test_a_new_podcast_rate_is_saved_with_the_episode() =
        runTest {
            val sync = sync()
            sync.changeSpeed(1.25, episode, positionMs = 20_000L, durationMs = 3_600_000L, isPlaying = true)
            runCurrent()
            assertEquals(1.25, sync.speed, 0.0)
            coVerify { api.savePlaybackState(episode, 20.0, 3600.0, 1.25, true) }
        }

    @Test
    fun test_the_replaced_current_item_keeps_its_place_in_history() =
        runTest {
            val sync = sync()
            val webEpisode = ListenCurrentMedia("9:web", "https://cdn.example.com/web.mp3", "audio", 300.0, 1800.0, "Web episode", "9", null)
            sync.keepReplacedInHistory(webEpisode, episode)
            runCurrent()
            coVerify(exactly = 1) { api.addToHistory(webEpisode.asQueueItem(), 300.0, 1800.0) }

            // Not the episode starting, not a story read aloud, and not one never started.
            sync.keepReplacedInHistory(webEpisode.copy(mediaUrl = episode.mediaUrl, storyHash = episode.storyHash), episode)
            sync.keepReplacedInHistory(webEpisode.copy(mediaType = "listen"), episode)
            sync.keepReplacedInHistory(webEpisode.copy(positionSeconds = 0.0), episode)
            runCurrent()
            coVerify(exactly = 1) { api.addToHistory(any(), any(), any()) }
        }

    @Test
    fun test_an_episode_this_app_saved_is_not_recorded_twice() =
        runTest {
            val sync = sync()
            // This app stopped it, which already recorded History with its latest position.
            sync.stopped(episode, positionMs = 90_000L, durationMs = 3_600_000L)
            val stale = ListenCurrentMedia(episode.storyHash, episode.mediaUrl, "audio", 80.0, 3600.0)
            val next = ListenQueueItem("7:ep2", "https://cdn.example.com/ep2.mp3", "audio", "Episode 2", "7", null)
            sync.keepReplacedInHistory(stale, next)
            runCurrent()
            coVerify(exactly = 1) { api.addToHistory(any(), any(), any()) }
            coVerify(exactly = 0) { api.addToHistory(any(), 80.0, any()) }
        }

    @Test
    fun test_a_seek_sends_the_new_position_right_away() =
        runTest {
            val sync = sync()
            sync.started(episode, positionMs = 0L, durationMs = 0L)
            now += 1_000L
            sync.seeked(episode, positionMs = 31_000L, durationMs = 3_600_000L, isPlaying = true)
            runCurrent()
            coVerify(exactly = 1) { api.syncPlaybackPosition(episode.mediaUrl, 31.0, 3600.0, 1.0, true) }
            // The seek counts as the latest position, so the next tick waits a full interval.
            now += 5_000L
            sync.playing(episode, positionMs = 36_000L, durationMs = 3_600_000L)
            runCurrent()
            coVerify(exactly = 1) { api.syncPlaybackPosition(any(), any(), any(), any(), any()) }
        }

    @Test
    fun test_a_story_read_aloud_is_saved_without_the_podcast_rate() =
        runTest {
            val sync = sync()
            sync.applyState(ListenPlaybackState(mediaSpeed = 1.5))
            val story = ListenQueueItem("4:s", ListenUpNextQueue.mediaUrl("4:s"), "listen", "Story", "4", null)
            sync.listening(story, positionMs = 12_000L, durationMs = 240_000L, isPlaying = true)
            runCurrent()
            coVerify(exactly = 1) { api.savePlaybackState(story, 12.0, 240.0, null, true) }
        }

    @Test
    fun test_an_account_change_drops_requests_not_yet_sent() =
        runTest {
            val sync = sync()
            sync.started(episode, positionMs = 5_000L, durationMs = 0L)
            sync.reset()
            runCurrent()
            coVerify(exactly = 0) { api.savePlaybackState(any(), any(), any(), any(), any()) }
            assertEquals(ListenMediaSettings(), sync.settings)
            assertEquals(1.0, sync.speed, 0.0)
        }
}
