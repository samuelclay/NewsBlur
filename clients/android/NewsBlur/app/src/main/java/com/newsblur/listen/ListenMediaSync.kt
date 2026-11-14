package com.newsblur.listen

import com.newsblur.network.ListenApi
import com.newsblur.util.Log
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.launch

/**
 * ListenMediaSync.kt keeps the web media player's shared state (apps/media_player) in step with a podcast episode
 * ListenManager.kt plays, so an episode paused here resumes on the web and the other way around:
 * - save_playback_state records the episode as the current item with its position as it starts, pauses, seeks, stops,
 *   and when the app goes to the background, like the web's save_durable_state in media_player_view.js; a story read
 *   aloud is saved as the current item too as it starts and pauses, as on the web and iOS;
 * - sync_playback_position sends the position every POSITION_SYNC_MS while it plays, the HTTP twin of the web's
 *   media:sync websocket message, which touches only Redis. When it answers that another device took over, this
 *   episode stops sending positions until it's saved as the current item again;
 * - add_to_media_history records where it stopped when it stops or finishes, as the web does when it moves on.
 * It never sends the settings back, so a skip interval changed on the web can't be overwritten with an old one, and
 * it sends the podcast rate only once it was changed here. It never clears the queue or History. Requests go out one
 * at a time, in order; a failed one is dropped, since the next save carries the position anyway.
 */
class ListenMediaSync(
    private val api: ListenApi,
    private val scope: CoroutineScope,
    private val clock: () -> Long,
) {
    /** The web's skip intervals, auto-play and remember-position settings, as playback_state last reported them. */
    var settings: ListenMediaSettings = ListenMediaSettings()
        private set

    /** The rate podcasts play at, kept apart from Listen's speed like the web's media_playback_rate. */
    var speed: Double = DEFAULT_SPEED
        private set

    private var lastPositionSentAt: Long? = null
    private var requests: Channel<suspend () -> Unit>? = null

    // The file this app last saved as the server's current item; it went to History when this app stopped it.
    private var lastSavedMediaUrl: String? = null

    // The podcast rate goes out only after it was changed here, so a rate chosen on the web is never overwritten.
    private var speedChangedHere = false

    // The file sync_playback_position said is no longer current: another device took over, so no more positions.
    @Volatile private var notCurrentMediaUrl: String? = null

    /** Takes the settings and podcast rate from a playback_state the server sent. */
    fun applyState(state: ListenPlaybackState) {
        settings = state.settings
        state.mediaSpeed?.let {
            speed = ListenSpeed.clamp(it)
            speedChangedHere = false
        }
    }

    /** The episode started at positionMs: it becomes the server's current item. */
    fun started(
        episode: ListenQueueItem,
        positionMs: Long,
        durationMs: Long,
        isPlaying: Boolean = true,
    ) {
        lastPositionSentAt = clock()
        save(episode, positionMs, durationMs, isPlaying)
    }

    /**
     * The episode about to start replaces the server's current item, so a different file paused part way on the web
     * or iOS goes to History first with its position, as the web's add_to_history_from_current does. One this app
     * saved went to History when it stopped here, with a newer position than playback_state may have had yet.
     */
    fun keepReplacedInHistory(
        current: ListenCurrentMedia?,
        episode: ListenQueueItem,
    ) {
        if (current == null || current.positionSeconds <= 0.0) return
        if (current.mediaType == ListenUpNextQueue.MEDIA_TYPE_LISTEN) return
        if (current.mediaUrl == lastSavedMediaUrl) return
        if (ListenMediaResume.isSameMedia(
                current.storyHash,
                current.mediaUrl,
                current.mediaType,
                episode.storyHash,
                episode.mediaUrl,
                episode.mediaType,
            )
        ) {
            return
        }
        send { api.addToHistory(current.asQueueItem(), current.positionSeconds, current.durationSeconds) }
    }

    /**
     * Called as the episode plays; sends the position at most once every POSITION_SYNC_MS, and not at all once another
     * device has taken over.
     */
    fun playing(
        episode: ListenQueueItem,
        positionMs: Long,
        durationMs: Long,
    ) {
        if (episode.mediaUrl == notCurrentMediaUrl) return
        val now = clock()
        val last = lastPositionSentAt
        if (last != null && now - last < POSITION_SYNC_MS) return
        lastPositionSentAt = now
        sendPosition(episode, positionMs, durationMs, isPlaying = true)
    }

    /** A seek or skip saves where it landed right away, like a pause. */
    fun seeked(
        episode: ListenQueueItem,
        positionMs: Long,
        durationMs: Long,
        isPlaying: Boolean,
    ) = saveNow(episode, positionMs, durationMs, isPlaying)

    /**
     * A story read aloud becomes the server's current item as it starts and pauses, so the web can pick it up. Its
     * speed is Listen's own, so the saved podcast rate is left alone.
     */
    fun listening(
        story: ListenQueueItem,
        positionMs: Long,
        durationMs: Long,
        isPlaying: Boolean,
    ) {
        save(story, positionMs, durationMs, isPlaying, rate = null)
    }

    private fun sendPosition(
        episode: ListenQueueItem,
        positionMs: Long,
        durationMs: Long,
        isPlaying: Boolean,
    ) {
        val rate = speed
        send {
            val result =
                api.syncPlaybackPosition(
                    mediaUrl = episode.mediaUrl,
                    positionSeconds = seconds(positionMs),
                    durationSeconds = seconds(durationMs),
                    playbackRate = rate,
                    isPlaying = isPlaying,
                )
            if (result == ListenPositionSync.NOT_CURRENT) notCurrentMediaUrl = episode.mediaUrl
        }
    }

    /** Pausing saves where it paused right away, as the web does on its pause event. */
    fun paused(
        episode: ListenQueueItem,
        positionMs: Long,
        durationMs: Long,
    ) = saveNow(episode, positionMs, durationMs, isPlaying = false)

    /** Saves the position now, whatever the throttle, for the app going to the background or being swiped away. */
    fun saveNow(
        episode: ListenQueueItem,
        positionMs: Long,
        durationMs: Long,
        isPlaying: Boolean,
    ) {
        lastPositionSentAt = clock()
        save(episode, positionMs, durationMs, isPlaying)
    }

    /** The episode was closed, or another one or a story read aloud took over: saved where it stopped, and History. */
    fun stopped(
        episode: ListenQueueItem,
        positionMs: Long,
        durationMs: Long,
    ) {
        saveNow(episode, positionMs, durationMs, isPlaying = false)
        recordHistory(episode, positionMs, durationMs)
    }

    /** The episode played to its end. */
    fun finished(
        episode: ListenQueueItem,
        durationMs: Long,
    ) = stopped(episode, durationMs, durationMs)

    /** A new podcast rate, saved with the episode playing, when there is one, as the web saves set_playback_rate. */
    fun changeSpeed(
        newSpeed: Double,
        episode: ListenQueueItem?,
        positionMs: Long,
        durationMs: Long,
        isPlaying: Boolean,
    ) {
        speed = ListenSpeed.clamp(newSpeed)
        speedChangedHere = true
        if (episode != null) saveNow(episode, positionMs, durationMs, isPlaying)
    }

    /** The account changed: nothing carries over to whoever signs in next. */
    fun reset() {
        settings = ListenMediaSettings()
        speed = DEFAULT_SPEED
        lastPositionSentAt = null
        lastSavedMediaUrl = null
        speedChangedHere = false
        notCurrentMediaUrl = null
        // Whatever hasn't gone out yet is dropped rather than sent under whoever signs in next.
        requests?.cancel()
        requests = null
    }

    private fun save(
        episode: ListenQueueItem,
        positionMs: Long,
        durationMs: Long,
        isPlaying: Boolean,
        rate: Double? = speed.takeIf { speedChangedHere },
    ) {
        lastSavedMediaUrl = episode.mediaUrl
        send {
            val saved =
                api.savePlaybackState(
                    item = episode,
                    positionSeconds = seconds(positionMs),
                    durationSeconds = seconds(durationMs),
                    playbackRate = rate,
                    isPlaying = isPlaying,
                )
            // Saved as the current item again, so its positions count once more. This runs after any position update
            // queued before it, so an older "not current" answer can't outlast it.
            if (saved != null && notCurrentMediaUrl == episode.mediaUrl) notCurrentMediaUrl = null
        }
    }

    private fun recordHistory(
        episode: ListenQueueItem,
        positionMs: Long,
        durationMs: Long,
    ) {
        send { api.addToHistory(episode, seconds(positionMs), seconds(durationMs)) }
    }

    /** Queues a request behind the ones already waiting, so a pause can never land before the start it follows. */
    private fun send(request: suspend () -> Unit) {
        val channel =
            requests ?: Channel<suspend () -> Unit>(Channel.UNLIMITED).also { created ->
                requests = created
                scope.launch {
                    for (next in created) {
                        try {
                            next()
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (failure: Exception) {
                            Log.w(ListenMediaSync::class.java.name, "Media player request failed: ${failure.message}")
                        }
                    }
                }
            }
        channel.trySend(request)
    }

    private fun seconds(ms: Long): Double = ms.coerceAtLeast(0L) / 1000.0

    companion object {
        /** The web's POSITION_SYNC_INTERVAL in media_player_view.js. */
        const val POSITION_SYNC_MS = 10_000L
        const val DEFAULT_SPEED = 1.0
    }
}
