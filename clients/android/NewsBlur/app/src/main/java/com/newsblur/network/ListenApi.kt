package com.newsblur.network

import com.newsblur.listen.ListenLibraryResponse
import com.newsblur.listen.ListenManifest
import com.newsblur.listen.ListenPlaybackState
import com.newsblur.listen.ListenPositionSync
import com.newsblur.listen.ListenQueueItem
import com.newsblur.listen.ListenResult
import com.newsblur.listen.ListenSegmentResponse
import com.newsblur.listen.ListenUsageResponse
import com.newsblur.listen.ListenVoicePreviewResponse
import com.newsblur.listen.ListenVoicesResponse

/** ListenApi.kt filters the ElevenLabs voice library through GET /listen/library. */
data class ListenLibraryQuery(
    val language: String,
    val filters: Map<String, String> = emptyMap(),
    val search: String = "",
    val sort: String? = null,
    val page: Int = 0,
)

/** ListenApi.kt asks POST /listen/preview for about ten seconds in a voice, optionally with unsaved delivery. */
data class ListenVoicePreviewRequest(
    val voiceId: String,
    val storyHash: String? = null,
    val language: String? = null,
    val delivery: String? = null,
    val stability: Double? = null,
    val similarity: Double? = null,
    val style: Double? = null,
    val speakerBoost: Boolean? = null,
)

/** ListenApi.kt tells POST /listen/progress how much of a story played, for usage stats nobody sees in the app. */
data class ListenProgressReport(
    val manifestId: String,
    val playedMs: Long,
    val speed: Double,
    val finished: Boolean,
)

interface ListenApi {
    suspend fun getVoices(language: String? = null): ListenResult<ListenVoicesResponse>

    suspend fun getLibrary(query: ListenLibraryQuery): ListenResult<ListenLibraryResponse>

    suspend fun getManifest(
        storyHash: String,
        language: String? = null,
        voiceId: String? = null,
    ): ListenResult<ListenManifest>

    suspend fun getSegment(
        manifestId: String,
        index: Int,
    ): ListenResult<ListenSegmentResponse>

    suspend fun getVoicePreview(request: ListenVoicePreviewRequest): ListenResult<ListenVoicePreviewResponse>

    suspend fun getUsage(): ListenResult<ListenUsageResponse>

    /** Returns whether the server took the report; callers drop it either way. */
    suspend fun reportProgress(report: ListenProgressReport): Boolean

    /** The shared Up Next queue and history (apps/media_player); null when the request failed. */
    suspend fun getPlaybackState(): ListenPlaybackState?

    /**
     * Adds to Up Next and returns the queue as the server now has it, or null on failure: at the end, or at
     * [position] in the whole queue, like the web's Play Next with 0.
     */
    suspend fun addToUpNext(
        item: ListenQueueItem,
        position: Int? = null,
    ): ListenPlaybackState?

    suspend fun removeFromUpNext(item: ListenQueueItem): ListenPlaybackState?

    /** Sends the whole queue in its new order, other media included, since the server drops what isn't listed. */
    suspend fun reorderUpNext(queue: List<ListenQueueItem>): ListenPlaybackState?

    /** Records a story that stopped playing, with where it stopped, so it can be resumed from History. */
    suspend fun addToHistory(
        item: ListenQueueItem,
        positionSeconds: Double,
        durationSeconds: Double,
    ): Boolean

    /**
     * Records the current item with its position (save_playback_state), so the web and iOS resume it there. Only the
     * current_* fields and is_playing go out, never the player settings. playbackRate is the podcast rate, and null
     * for a story read aloud, which leaves the saved podcast rate alone as the web does.
     */
    suspend fun savePlaybackState(
        item: ListenQueueItem,
        positionSeconds: Double,
        durationSeconds: Double,
        playbackRate: Double?,
        isPlaying: Boolean,
    ): ListenPlaybackState?

    /**
     * The frequent position update while an episode plays (sync_playback_position), which only touches Redis and only
     * while mediaUrl is still the server's current item; NOT_CURRENT means another device took over.
     */
    suspend fun syncPlaybackPosition(
        mediaUrl: String,
        positionSeconds: Double,
        durationSeconds: Double,
        playbackRate: Double,
        isPlaying: Boolean,
    ): ListenPositionSync

    /** Segment and preview URLs may be relative to the NewsBlur server the app is signed in to. */
    fun resolveAudioUrl(url: String): String

    /** The app's User-Agent, which the audio player sends to the stream server too. */
    val audioUserAgent: String
}
