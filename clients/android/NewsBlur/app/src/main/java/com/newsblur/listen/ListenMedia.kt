package com.newsblur.listen

/**
 * An audio file a story carries, like a podcast episode, that ListenManager.kt plays instead of reading the story
 * aloud. storyMedia.js finds it in the story's <audio> elements, which utils/story_functions.py makes from a feed's
 * audio enclosures.
 */
data class ListenMedia(
    val url: String,
    val type: String = ListenUpNextQueue.MEDIA_TYPE_AUDIO,
    /** The story's first image, which the web sends as the episode's image_url. */
    val imageUrl: String? = null,
) {
    /**
     * The address ExoPlayer streams from. Android refuses plain http, which many older podcast feeds still list, and
     * nearly every podcast host serves the same file over https.
     */
    val streamUrl: String
        get() = if (url.startsWith("http://", ignoreCase = true)) "https://" + url.substring("http://".length) else url
}

/** The web media player's settings (apps/media_player/models.py), chosen in media_player_settings_popover.js. */
data class ListenMediaSettings(
    val skipBackSeconds: Int = DEFAULT_SKIP_BACK_SECONDS,
    val skipForwardSeconds: Int = DEFAULT_SKIP_FORWARD_SECONDS,
    val autoPlayNext: Boolean = true,
    val rememberPosition: Boolean = true,
) {
    val skipBackMs: Long
        get() = skipBackSeconds * 1000L

    val skipForwardMs: Long
        get() = skipForwardSeconds * 1000L

    companion object {
        const val DEFAULT_SKIP_BACK_SECONDS = 15
        const val DEFAULT_SKIP_FORWARD_SECONDS = 30
    }
}

/** What sync_playback_position said about a position update. */
enum class ListenPositionSync {
    /** {"code": 1}: the position is in Redis for the web and iOS to resume from. */
    SYNCED,

    /** Code -1: another device made something else the current item, so this one stops sending positions. */
    NOT_CURRENT,

    /** Nothing usable came back (offline, or a server without the endpoint); the next update tries again. */
    FAILED,
}

/** What playback_state says the web, iOS or this app last played, and where it was. */
data class ListenCurrentMedia(
    val storyHash: String,
    val mediaUrl: String,
    val mediaType: String,
    val positionSeconds: Double,
    val durationSeconds: Double,
    val title: String = "",
    val feedId: String? = null,
    val imageUrl: String? = null,
) {
    /** The current item as a queue or History entry, for keeping its place in History when something replaces it. */
    fun asQueueItem(): ListenQueueItem = ListenQueueItem(storyHash, mediaUrl, mediaType, title, feedId, imageUrl)
}

/**
 * ListenMediaResume.kt picks where an episode starts, so one paused on the web or iOS resumes here: the saved
 * position of the server's current item when it's this episode, else of this episode's History entry, the same
 * position the web's History plays from. With the web's "Remember position" off, every episode starts at the top.
 */
object ListenMediaResume {
    /** A position this close to the end means the episode finished, so it plays again from the start. */
    const val FINISHED_MARGIN_MS = 5_000L

    fun startPositionMs(
        state: ListenPlaybackState?,
        storyHash: String,
        mediaUrl: String,
        mediaType: String = ListenUpNextQueue.MEDIA_TYPE_AUDIO,
    ): Long {
        if (state == null || !state.settings.rememberPosition) return 0L
        val current = state.current
        val (positionSeconds, durationSeconds) =
            when {
                current != null && isSameMedia(current.storyHash, current.mediaUrl, current.mediaType, storyHash, mediaUrl, mediaType) ->
                    current.positionSeconds to current.durationSeconds
                else ->
                    // The exact file first: a story's other enclosure only counts when this one was never played.
                    (
                        state.history.firstOrNull { it.item.mediaUrl == mediaUrl }
                            ?: state.history.firstOrNull {
                                isSameMedia(it.item.storyHash, it.item.mediaUrl, it.item.mediaType, storyHash, mediaUrl, mediaType)
                            }
                    )?.let { it.positionSeconds to it.durationSeconds } ?: return 0L
            }
        val positionMs = (positionSeconds * 1000.0).toLong()
        val durationMs = (durationSeconds * 1000.0).toLong()
        if (positionMs <= 0L) return 0L
        if (durationMs > 0L && positionMs >= durationMs - FINISHED_MARGIN_MS) return 0L
        return positionMs
    }

    /**
     * The same media: the same file, or failing that the same story with the same media type, so a file URL that
     * changed between visits still resumes. The story read aloud, or its video, never counts, since its position is
     * in other audio.
     */
    fun isSameMedia(
        savedStoryHash: String,
        savedMediaUrl: String,
        savedMediaType: String,
        storyHash: String,
        mediaUrl: String,
        mediaType: String = ListenUpNextQueue.MEDIA_TYPE_AUDIO,
    ): Boolean {
        if (savedMediaUrl == mediaUrl) return true
        return savedMediaType == mediaType &&
            savedStoryHash.isNotEmpty() &&
            savedStoryHash == storyHash
    }
}
