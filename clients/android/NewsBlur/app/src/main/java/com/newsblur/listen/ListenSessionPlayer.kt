package com.newsblur.listen

import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.SimpleBasePlayer
import androidx.media3.common.util.UnstableApi
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/**
 * ListenSessionPlayer.kt is the player ListenPlaybackService.kt hands to the media session. It shows the lock
 * screen, notification and Bluetooth controls one story with its whole duration, while ListenManager.kt plays
 * the story's segments back to back on an ExoPlayer underneath. The next playlist item is the next unread
 * story, so "next" continues the list just like auto-continue does.
 */
@OptIn(UnstableApi::class)
class ListenSessionPlayer(
    looper: Looper,
    private val manager: ListenManager,
) : SimpleBasePlayer(looper) {
    private var reportedDiscontinuity = 0

    /** Called by ListenManager.kt on the main thread whenever playback changes. */
    fun refresh() {
        invalidateState()
    }

    override fun getState(): State {
        val snapshot = manager.sessionSnapshot()
        val builder =
            State
                .Builder()
                .setAvailableCommands(commands(snapshot.hasNext))
                .setPlayWhenReady(
                    snapshot.playWhenReady,
                    Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST,
                ).setPlaybackParameters(PlaybackParameters(snapshot.speed))
                .setSeekBackIncrementMs(ListenSeek.SKIP_BACK_MS)
                .setSeekForwardIncrementMs(ListenSeek.SKIP_FORWARD_MS)
                .setAudioAttributes(AUDIO_ATTRIBUTES)

        val story = snapshot.story
        if (story == null) {
            return builder
                .setPlaylist(emptyList())
                .setPlaybackState(Player.STATE_IDLE)
                .build()
        }

        val playlist = mutableListOf(storyItem(story, snapshot))
        // SimpleBasePlayer.java rejects a playlist that holds the same story twice.
        snapshot.next?.takeIf { it.storyHash != story.storyHash }?.let { next ->
            playlist +=
                MediaItemData
                    .Builder(next.storyHash)
                    .setMediaItem(
                        MediaItem
                            .Builder()
                            .setMediaId(next.storyHash)
                            .setMediaMetadata(
                                MediaMetadata
                                    .Builder()
                                    .setTitle(next.title)
                                    .setArtist(next.feedTitle)
                                    .build(),
                            ).build(),
                    ).setIsSeekable(false)
                    .build()
        }

        builder
            .setPlaylist(playlist)
            .setCurrentMediaItemIndex(0)
            .setPlaybackState(snapshot.playbackState)
            .setIsLoading(snapshot.playbackState == Player.STATE_BUFFERING)
            .setContentPositionMs { manager.logicalPositionMs() }
            .setContentBufferedPositionMs { manager.logicalBufferedPositionMs() }

        // ListenSessionPlayer.kt reports each jump ListenManager.kt makes once, so the lock screen's
        // progress restarts from the new place instead of extrapolating the old one.
        if (snapshot.discontinuity != reportedDiscontinuity) {
            reportedDiscontinuity = snapshot.discontinuity
            builder.setPositionDiscontinuity(
                Player.DISCONTINUITY_REASON_SEEK,
                manager.logicalPositionMs(),
            )
        }
        return builder.build()
    }

    private fun storyItem(
        story: ListenStory,
        snapshot: ListenSessionSnapshot,
    ): MediaItemData {
        val metadata =
            MediaMetadata
                .Builder()
                .setTitle(story.title)
                .setDisplayTitle(story.title)
                .setArtist(story.feedTitle)
                .setAlbumTitle(story.feedTitle)
                .setIsPlayable(true)
                .setIsBrowsable(false)
                .apply {
                    snapshot.artwork?.let {
                        setArtworkData(it, MediaMetadata.PICTURE_TYPE_FRONT_COVER)
                    }
                }.build()
        return MediaItemData
            .Builder(story.storyHash)
            .setMediaItem(
                MediaItem
                    .Builder()
                    .setMediaId(story.storyHash)
                    .setMediaMetadata(metadata)
                    .build(),
            ).setMediaMetadata(metadata)
            .setIsSeekable(snapshot.durationMs > 0)
            .setDurationUs(
                if (snapshot.durationMs >
                    0
                ) {
                    snapshot.durationMs * 1000
                } else {
                    C.TIME_UNSET
                },
            ).build()
    }

    override fun handleSetPlayWhenReady(playWhenReady: Boolean): ListenableFuture<*> {
        manager.setPlayWhenReady(playWhenReady)
        return Futures.immediateVoidFuture()
    }

    override fun handlePrepare(): ListenableFuture<*> {
        manager.retryIfFailed()
        return Futures.immediateVoidFuture()
    }

    override fun handleStop(): ListenableFuture<*> {
        manager.setPlayWhenReady(false)
        return Futures.immediateVoidFuture()
    }

    override fun handleRelease(): ListenableFuture<*> = Futures.immediateVoidFuture()

    override fun handleSetPlaybackParameters(playbackParameters: PlaybackParameters): ListenableFuture<*> {
        manager.setSpeed(playbackParameters.speed.toDouble())
        return Futures.immediateVoidFuture()
    }

    override fun handleSeek(
        mediaItemIndex: Int,
        positionMs: Long,
        seekCommand: Int,
    ): ListenableFuture<*> {
        when {
            seekCommand == Player.COMMAND_SEEK_TO_NEXT ||
                seekCommand == Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM ||
                mediaItemIndex > 0 -> manager.playNext()
            seekCommand == Player.COMMAND_SEEK_BACK -> manager.skipBack()
            seekCommand == Player.COMMAND_SEEK_FORWARD -> manager.skipForward()
            positionMs == C.TIME_UNSET -> manager.seekTo(0L)
            else -> manager.seekTo(positionMs)
        }
        return Futures.immediateVoidFuture()
    }

    private fun commands(hasNext: Boolean): Player.Commands =
        Player.Commands
            .Builder()
            .addAll(
                Player.COMMAND_PLAY_PAUSE,
                Player.COMMAND_PREPARE,
                Player.COMMAND_STOP,
                Player.COMMAND_SEEK_TO_DEFAULT_POSITION,
                Player.COMMAND_SEEK_IN_CURRENT_MEDIA_ITEM,
                Player.COMMAND_SEEK_BACK,
                Player.COMMAND_SEEK_FORWARD,
                Player.COMMAND_SET_SPEED_AND_PITCH,
                Player.COMMAND_GET_CURRENT_MEDIA_ITEM,
                Player.COMMAND_GET_TIMELINE,
                Player.COMMAND_GET_METADATA,
                Player.COMMAND_GET_AUDIO_ATTRIBUTES,
                Player.COMMAND_RELEASE,
            ).addIf(Player.COMMAND_SEEK_TO_NEXT, hasNext)
            .addIf(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM, hasNext)
            .build()

    companion object {
        val AUDIO_ATTRIBUTES: AudioAttributes =
            AudioAttributes
                .Builder()
                .setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_SPEECH)
                .build()
    }
}

/** What ListenManager.kt tells ListenSessionPlayer.kt about the story playing now. */
class ListenSessionSnapshot(
    val story: ListenStory?,
    val next: ListenStory?,
    val playWhenReady: Boolean,
    val playbackState: Int,
    val durationMs: Long,
    val speed: Float,
    val artwork: ByteArray?,
    val discontinuity: Int,
) {
    val hasNext: Boolean
        get() = next != null
}
