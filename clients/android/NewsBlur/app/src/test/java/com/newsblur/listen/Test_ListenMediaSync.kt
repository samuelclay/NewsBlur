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
 * episode: saved as it starts, pauses and seeks, its position sent at most every ten seconds while it plays and not
 * at all once another device takes over, History when it stops or finishes, the skip intervals and podcast rate taken
 * from the server, and the rate sent back only once it was changed here.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class Test_ListenMediaSync {
    private val api = mockk<ListenApi>()
    private var now = 1_000_000L
    private val episode = ListenQueueItem("7:ep1", "https://cdn.example.com/ep1.mp3", "audio", "Episode 1", "7", null)

    private fun TestScope.sync(): ListenMediaSync {
        coEvery { api.savePlaybackState(any(), any(), any(), any(), any()) } returns ListenPlaybackState()
        coEvery { api.syncPlaybackPosition(any(), any(), any(), any(), any()) } returns ListenPositionSync.SYNCED
        coEvery { api.addToHistory(any(), any(), any()) } returns true
        return ListenMediaSync(api, backgroundScope) { now }
    }

    @Test
    fun test_starting_saves_the_episode_as_current_and_playing() =
        runTest {
            val sync = sync()
            sync.started(episode, positionMs = 754_200L, durationMs = 0L)
            runCurrent()
            coVerify(exactly = 1) { api.savePlaybackState(episode, 754.2, 0.0, null, true) }
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
                api.savePlaybackState(episode, 0.0, 0.0, null, true)
                api.savePlaybackState(episode, 3.0, 3600.0, null, false)
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
            coVerify(exactly = 1) { api.savePlaybackState(episode, 1.0, 3600.0, null, true) }
        }

    @Test
    fun test_stopping_saves_the_place_then_records_history() =
        runTest {
            val sync = sync()
            sync.stopped(episode, positionMs = 61_500L, durationMs = 3_600_000L)
            runCurrent()
            coVerifyOrder {
                api.savePlaybackState(episode, 61.5, 3600.0, null, false)
                api.addToHistory(episode, 61.5, 3600.0)
            }
        }

    @Test
    fun test_finishing_records_the_end_of_the_episode() =
        runTest {
            val sync = sync()
            sync.finished(episode, durationMs = 3_600_000L)
            runCurrent()
            coVerify { api.savePlaybackState(episode, 3600.0, 3600.0, null, false) }
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
            assertEquals(1.5, sync.speed, 0.0)
            sync.started(episode, positionMs = 0L, durationMs = 0L)
            runCurrent()
            // The rate came from the web, so it isn't sent back over a newer one chosen there.
            coVerify { api.savePlaybackState(episode, 0.0, 0.0, null, true) }
        }

    @Test
    fun test_a_new_podcast_rate_is_saved_with_the_episode() =
        runTest {
            val sync = sync()
            sync.changeSpeed(1.25, episode, positionMs = 20_000L, durationMs = 3_600_000L, isPlaying = true)
            now += 2_000L
            sync.paused(episode, positionMs = 22_000L, durationMs = 3_600_000L)
            runCurrent()
            assertEquals(1.25, sync.speed, 0.0)
            coVerify { api.savePlaybackState(episode, 20.0, 3600.0, 1.25, true) }
            // Once changed here, later saves keep carrying it, until the server's own state is read again.
            coVerify { api.savePlaybackState(episode, 22.0, 3600.0, 1.25, false) }
            sync.applyState(ListenPlaybackState(mediaSpeed = 1.25))
            sync.paused(episode, positionMs = 23_000L, durationMs = 3_600_000L)
            runCurrent()
            coVerify { api.savePlaybackState(episode, 23.0, 3600.0, null, false) }
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
    fun test_a_seek_saves_where_it_landed_right_away() =
        runTest {
            val sync = sync()
            sync.started(episode, positionMs = 0L, durationMs = 0L)
            now += 1_000L
            sync.seeked(episode, positionMs = 31_000L, durationMs = 3_600_000L, isPlaying = true)
            runCurrent()
            coVerify(exactly = 1) { api.savePlaybackState(episode, 31.0, 3600.0, null, true) }
            // The seek counts as the latest position, so the next tick waits a full interval.
            now += 5_000L
            sync.playing(episode, positionMs = 36_000L, durationMs = 3_600_000L)
            runCurrent()
            coVerify(exactly = 0) { api.syncPlaybackPosition(any(), any(), any(), any(), any()) }
        }

    @Test
    fun test_positions_stop_once_another_device_takes_over() =
        runTest {
            val sync = sync()
            coEvery { api.syncPlaybackPosition(any(), any(), any(), any(), any()) } returns ListenPositionSync.NOT_CURRENT
            sync.started(episode, positionMs = 0L, durationMs = 0L)
            now += 10_000L
            sync.playing(episode, positionMs = 10_000L, durationMs = 3_600_000L)
            runCurrent()
            coVerify(exactly = 1) { api.syncPlaybackPosition(any(), any(), any(), any(), any()) }
            // Code -1 is never retried, however long it keeps playing.
            repeat(5) {
                now += 10_000L
                sync.playing(episode, positionMs = 20_000L + it * 10_000L, durationMs = 3_600_000L)
            }
            runCurrent()
            coVerify(exactly = 1) { api.syncPlaybackPosition(any(), any(), any(), any(), any()) }
            // Pausing here saves it as the current item again, so positions count once more.
            coEvery { api.syncPlaybackPosition(any(), any(), any(), any(), any()) } returns ListenPositionSync.SYNCED
            sync.paused(episode, positionMs = 70_000L, durationMs = 3_600_000L)
            runCurrent()
            now += 10_000L
            sync.playing(episode, positionMs = 80_000L, durationMs = 3_600_000L)
            runCurrent()
            coVerify(exactly = 2) { api.syncPlaybackPosition(any(), any(), any(), any(), any()) }
        }

    @Test
    fun test_a_failed_position_update_tries_again_next_interval() =
        runTest {
            val sync = sync()
            coEvery { api.syncPlaybackPosition(any(), any(), any(), any(), any()) } returns ListenPositionSync.FAILED
            sync.started(episode, positionMs = 0L, durationMs = 0L)
            repeat(3) {
                now += 10_000L
                sync.playing(episode, positionMs = (it + 1) * 10_000L, durationMs = 3_600_000L)
                runCurrent()
            }
            coVerify(exactly = 3) { api.syncPlaybackPosition(any(), any(), any(), any(), any()) }
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
