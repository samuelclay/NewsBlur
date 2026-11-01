package com.newsblur.listen

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.annotation.MainThread
import androidx.annotation.OptIn
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.extractor.DefaultExtractorsFactory
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.ListenableFuture
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.di.IconFileCache
import com.newsblur.domain.Feed
import com.newsblur.domain.Story
import com.newsblur.network.ListenApi
import com.newsblur.network.ListenProgressReport
import com.newsblur.preference.ListenPreferences
import com.newsblur.preference.ListenSettings
import com.newsblur.util.FeedUtils
import com.newsblur.util.FileCache
import com.newsblur.util.Log
import com.newsblur.util.NBScope
import com.newsblur.util.UIUtils
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/** A story Listen can play, with what the player and lock screen show about it. */
data class ListenStory(
    val storyHash: String,
    val title: String,
    val feedId: String?,
    val feedTitle: String?,
    val faviconUrl: String?,
    val feedColor: String?,
    val feedFade: String?,
    /** This device's copy of the story, or null for one queued elsewhere; ListenStoryRead.kt marks either read. */
    val story: Story?,
)

enum class ListenPhase {
    IDLE,
    LOADING,
    BUFFERING,
    READY,
    PREVIEW_ENDED,
    ENDED,
    ERROR,
}

data class ListenUiState(
    val story: ListenStory? = null,
    val phase: ListenPhase = ListenPhase.IDLE,
    val playWhenReady: Boolean = false,
    val positionMs: Long = 0L,
    val durationMs: Long = 0L,
    val segmentIndex: Int = 0,
    val paragraphs: List<ListenParagraph> = emptyList(),
    val segments: List<ListenSegment> = emptyList(),
    val voice: ListenVoice? = null,
    val voiceFallback: Boolean = false,
    val language: String? = null,
    /** "original" when Listen reads the extracted article because the feed only carries a summary. */
    val textSource: String? = null,
    val isPreview: Boolean = false,
    val previewLimitMs: Long = 0L,
    val speed: Double = ListenSettings.DEFAULT_SPEED,
    val error: ListenError? = null,
    val usage: ListenUsage? = null,
    /** The stories auto-continue plays from the list Listen started in, after Up Next (ListenAutoContinue.kt). */
    val upNext: List<ListenStory> = emptyList(),
    /** Your Up Next queue, shared with the web and iOS (ListenUpNext.kt), in play order. */
    val queued: List<ListenStory> = emptyList(),
    /** The feed or folder upNext comes from, for "Then from …". */
    val upNextSource: String? = null,
) {
    fun isQueued(storyHash: String?): Boolean = storyHash != null && queued.any { it.storyHash == storyHash }

    /** What the next button and the lock screen's next play: Up Next first, then auto-continue. */
    val nextStory: ListenStory?
        get() = queued.firstOrNull { !isStory(it.storyHash) } ?: upNext.firstOrNull { !isStory(it.storyHash) }

    val isActive: Boolean
        get() = story != null

    val isLoading: Boolean
        get() = phase == ListenPhase.LOADING || phase == ListenPhase.BUFFERING

    /** Whether the play button should read as pause: playing, or about to. */
    val showsPause: Boolean
        get() = playWhenReady && (phase == ListenPhase.READY || isLoading)

    val highlightedParagraphs: List<Int>
        get() =
            if (phase == ListenPhase.IDLE ||
                phase == ListenPhase.ENDED
            ) {
                emptyList()
            } else {
                segments.getOrNull(segmentIndex)?.paragraphs.orEmpty()
            }

    fun isStory(storyHash: String?): Boolean = storyHash != null && story?.storyHash == storyHash
}

sealed interface ListenEvent {
    /** Auto-continue moved from one story to the next; a reader showing the old one can follow along. */
    data class Advanced(
        val fromStoryHash: String,
        val to: ListenStory,
    ) : ListenEvent
}

/**
 * ListenManager.kt runs Listen for the whole app: it fetches the story manifest, requests each segment's
 * audio as the one before it starts (never more than one ahead), plays them back to back on an ExoPlayer,
 * presents them as one story through ListenSessionPlayer.kt, and handles previews, retries, expiring
 * manifests and auto-continue. Everything here runs on the main thread.
 */
@OptIn(UnstableApi::class)
@Singleton
class ListenManager
    @Inject
    constructor(
        @param:ApplicationContext private val context: Context,
        private val listenApi: ListenApi,
        private val listenPreferences: ListenPreferences,
        private val feedUtils: FeedUtils,
        private val dbHelper: BlurDatabaseHelper,
        @param:IconFileCache private val iconCache: FileCache,
        private val storyRead: ListenStoryRead,
    ) {
        private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        private val mutableState =
            MutableStateFlow(ListenUiState(speed = listenPreferences.current().speed))
        val state: StateFlow<ListenUiState> = mutableState.asStateFlow()

        private val mutableEvents = MutableSharedFlow<ListenEvent>(extraBufferCapacity = 4)
        val events: SharedFlow<ListenEvent> = mutableEvents.asSharedFlow()

        private val mutableIcon = MutableStateFlow<Bitmap?>(null)

        /** The feed icon of the story playing, for the mini player and Now Playing. */
        val icon: StateFlow<Bitmap?> = mutableIcon.asStateFlow()

        val sessionPlayer: ListenSessionPlayer by lazy {
            ListenSessionPlayer(Looper.getMainLooper(), this)
        }

        private var exoPlayer: ExoPlayer? = null
        private var controllerFuture: ListenableFuture<MediaController>? = null

        // One story's playback. Every async result checks generation so a stale story can't touch a newer one.
        private var generation = 0
        private var storyJob: Job = SupervisorJob()
        private var story: ListenStory? = null

        // The story list Listen was started from, as captured; ListenStory copies are built only for Up Next.
        private var queue: List<Story> = emptyList()
        private var upNext: List<ListenStory> = emptyList()
        private var queueSource: String? = null

        // Saved and Read Stories hold only read stories, so auto-continue follows their order instead of skipping reads.
        private var queueFollowsListOrder = false

        // The last story played from the captured list, so auto-continue picks up there after queued stories.
        private var continueFromHash: String? = null

        // Up Next, the queue shared through apps/media_player (ListenUpNext.kt). Changes show at once and go to
        // the server one at a time; the server's answer replaces the local copy once nothing else is on its way.
        private var upNextQueue: List<ListenQueueItem> = emptyList()
        private var queuedStories: List<ListenStory> = emptyList()
        private var pendingQueueChanges = 0
        private var upNextQueueLoaded = false
        private val queueMutex = Mutex()
        private var manifest: ListenManifest? = null
        private var timeline = ListenTimeline(emptyList())
        private var phase = ListenPhase.IDLE
        private var playWhenReady = false
        private var currentSegment = 0
        private var lastOffsetMs = 0L
        private var waitingForSegment: Int? = null
        private var error: ListenError? = null
        private var usage: ListenUsage? = null
        private var speed = listenPreferences.current().speed
        private var artworkPng: ByteArray? = null
        private var discontinuity = 0
        private var loadAttempt = 0

        private val segmentUrls = mutableMapOf<Int, CachedUrl>()
        private val pendingSegments = mutableSetOf<Int>()
        private val segmentFailures = mutableMapOf<Int, ListenError>()
        private val playbackRetries = mutableMapOf<Int, Int>()
        private var tickJob: Job? = null

        // Each playSegment call takes a new number; a segment URL that arrives for an older one is dropped.
        private var playRequest = 0

        // A seek outside what ExoPlayer holds waits here until the scrubbing settles (seekToUnloaded).
        private var seekJob: Job? = null

        // ListenPlayedTime.kt counts the timeline that really played, reported to POST /listen/progress.
        private val playedTime = ListenPlayedTime()
        private var lastProgressReportAt = 0L

        init {
            scope.launch {
                // Up Next can change on the web or iOS while the app is away, so it's read again on return.
                ProcessLifecycleOwner.get().lifecycle.addObserver(
                    object : DefaultLifecycleObserver {
                        override fun onStart(owner: LifecycleOwner) {
                            if (story != null) refreshUpNextQueue()
                        }
                    },
                )
            }
            scope.launch {
                listenPreferences.settings.collect { settings ->
                    // Speed changed from Settings or another device's sync.
                    if (ListenSpeed.clamp(settings.speed) != speed) applySpeed(settings.speed, save = false)
                }
            }
        }

        // region Commands

        /**
         * Starts this story, or toggles it when it's already the one loaded. [queueStories] is the list it was
         * opened from, which auto-continue follows: its next unread story, or with [followsListOrder] simply its next
         * story (ListenAutoContinue.kt).
         */
        @MainThread
        fun listen(
            story: Story,
            queueStories: List<Story>,
            sourceName: String? = null,
            followsListOrder: Boolean = false,
        ) {
            if (this.story?.storyHash == story.storyHash) {
                togglePlayPause()
                return
            }
            // Listen always plays now; the story that was playing goes to History (startStory).
            val target = storyFor(story)
            queue = queueStories.ifEmpty { listOf(story) }
            queueSource = sourceName
            queueFollowsListOrder = followsListOrder
            startStory(target, startParagraph = 0, language = null, voiceId = null)
        }

        @MainThread
        fun togglePlayPause() {
            when (phase) {
                ListenPhase.IDLE -> Unit
                ListenPhase.ERROR -> retry()
                ListenPhase.PREVIEW_ENDED, ListenPhase.ENDED -> {
                    seekTo(0L)
                    setPlayWhenReady(true)
                }
                else -> setPlayWhenReady(!playWhenReady)
            }
        }

        @MainThread
        fun setPlayWhenReady(play: Boolean) {
            if (story == null) return
            if (play && phase == ListenPhase.ERROR) {
                retry()
                return
            }
            if (play && (phase == ListenPhase.PREVIEW_ENDED || phase == ListenPhase.ENDED)) {
                seekTo(0L)
            }
            playWhenReady = play
            exoPlayer?.let { player ->
                if (play) player.volume = previewVolume()
                // While a seek settles, ExoPlayer still holds the old position; playSegment starts the new one.
                if (seekJob?.isActive != true) player.playWhenReady = play
            }
            ensureService()
            publish()
        }

        @MainThread
        fun seekTo(positionMs: Long) {
            val player = exoPlayer
            val loadedManifest = manifest
            if (story == null || loadedManifest == null) return
            val target = positionMs.coerceIn(0L, seekableDurationMs())
            val location = timeline.locate(target)
            // Seeks and skips aren't listening: count up to here, then start again where playback lands.
            sampleProgress()
            playedTime.jumped()
            seekJob?.cancel()
            seekJob = null
            discontinuity++
            if (phase == ListenPhase.PREVIEW_ENDED || phase == ListenPhase.ENDED) {
                phase = ListenPhase.READY
            }
            val exoIndex = player?.let { exoIndexOf(it, location.segmentIndex) }
            when {
                player == null || exoIndex == null -> seekToUnloaded(location.segmentIndex, location.offsetMs)
                exoIndex == player.currentMediaItemIndex -> {
                    if (player.isCurrentMediaItemSeekable ||
                        location.offsetMs < SEEK_FROM_START_MS
                    ) {
                        player.seekTo(location.offsetMs)
                    } else {
                        // A segment that was streamed live can't seek, but its stream URL now redirects to the
                        // cached, seekable copy, so loading it again lands on the right moment.
                        reloadSegment(location.segmentIndex, location.offsetMs)
                    }
                }
                else -> player.seekTo(exoIndex, location.offsetMs)
            }
            // A seek back into what ExoPlayer holds may follow one that paused it to settle.
            if (seekJob == null) player?.playWhenReady = playWhenReady
            currentSegment = location.segmentIndex
            lastOffsetMs = location.offsetMs
            exoPlayer?.volume = previewVolume()
            publish()
        }

        /**
         * A seek outside the segments ExoPlayer holds needs /listen/segment, and every segment asked for counts
         * against the weekly cap, so scrubbing or skipping across the story asks only for where it settles.
         * The scrubber shows the new position right away while the old audio holds.
         */
        private fun seekToUnloaded(
            segmentIndex: Int,
            offsetMs: Long,
        ) {
            // Any segment URL still on its way is for an older target now.
            playRequest++
            waitingForSegment = null
            phase = ListenPhase.BUFFERING
            exoPlayer?.playWhenReady = false
            seekJob =
                launchForStory {
                    delay(SEEK_SETTLE_MS)
                    seekJob = null
                    playSegment(segmentIndex, offsetMs)
                }
        }

        @MainThread
        fun skipBack() =
            seekTo(
                ListenSeek.target(
                    logicalPositionMs(),
                    -ListenSeek.SKIP_BACK_MS,
                    seekableDurationMs(),
                ),
            )

        @MainThread
        fun skipForward() =
            seekTo(
                ListenSeek.target(
                    logicalPositionMs(),
                    ListenSeek.SKIP_FORWARD_MS,
                    seekableDurationMs(),
                ),
            )

        /** Paragraph taps in the story (listenFollowAlong.js) jump to the first segment reading that paragraph. */
        @MainThread
        fun seekToParagraph(
            storyHash: String,
            paragraphIndex: Int,
        ) {
            if (story?.storyHash != storyHash) return
            val segments = manifest?.segments ?: return
            val segment = ListenSegments.segmentForParagraph(segments, paragraphIndex) ?: return
            seekTo(timeline.startMs(segment))
            if (!playWhenReady) setPlayWhenReady(true)
        }

        @MainThread
        fun setSpeed(newSpeed: Double) = applySpeed(newSpeed, save = true)

        @MainThread
        fun playNext() {
            val next = nextAfterCurrent() ?: return
            startStory(next, startParagraph = 0, language = null, voiceId = null)
        }

        /** Plays a story from Up Next or the auto-continue list now; a queued one leaves Up Next as it starts. */
        @MainThread
        fun playQueued(storyHash: String) {
            val target =
                queuedStories.firstOrNull { it.storyHash == storyHash }
                    ?: upNext.firstOrNull { it.storyHash == storyHash }
                    ?: queue.firstOrNull { it.storyHash == storyHash }?.let(::storyFor)
                    ?: return
            startStory(target, startParagraph = 0, language = null, voiceId = null)
        }

        /** Adds a story to the end of Up Next and returns where it landed, 1 for first, for the confirmation. */
        @MainThread
        fun addToUpNext(source: Story): Int {
            val item = queueItemFor(storyFor(source))
            upNextQueue = ListenUpNextQueue.appended(upNextQueue, item)
            val position = ListenUpNextQueue.positionOf(upNextQueue, item.storyHash) ?: 1
            queueChanged()
            sendQueueChange { listenApi.addToUpNext(item) }
            return position
        }

        @MainThread
        fun removeFromUpNext(storyHash: String) {
            val item = ListenUpNextQueue.listenItems(upNextQueue).firstOrNull { it.storyHash == storyHash } ?: return
            upNextQueue = ListenUpNextQueue.without(upNextQueue, storyHash)
            queueChanged()
            sendQueueChange { listenApi.removeFromUpNext(item) }
        }

        /** Moves an Up Next story, counting positions as Up Next shows them; podcasts queued on the web stay put. */
        @MainThread
        fun moveInUpNext(
            from: Int,
            to: Int,
        ) {
            val reordered = ListenUpNextQueue.moved(upNextQueue, from, to)
            if (reordered == upNextQueue) return
            upNextQueue = reordered
            queueChanged()
            sendQueueChange { listenApi.reorderUpNext(reordered) }
        }

        /** Reads Up Next from the server, as Now Playing opens and when the app returns to the foreground. */
        @MainThread
        fun refreshUpNextQueue() {
            if (pendingQueueChanges > 0) return
            scope.launch {
                val state = listenApi.getPlaybackState() ?: return@launch
                // A change made while this was on its way is newer than what came back.
                if (pendingQueueChanges > 0) return@launch
                applyServerQueue(state.queue)
            }
        }

        @MainThread
        fun retry() {
            val current = story ?: return
            error = null
            val loadedManifest = manifest
            if (loadedManifest == null) {
                startStory(current, startParagraph = 0, language = null, voiceId = null)
                return
            }
            playbackRetries.remove(currentSegment)
            segmentFailures.clear()
            playWhenReady = true
            playSegment(currentSegment, lastOffsetMs)
        }

        /** The session's prepare command, sent by a play press after an error. */
        @MainThread
        fun retryIfFailed() {
            if (phase == ListenPhase.ERROR) retry()
        }

        /**
         * After a new voice or delivery is saved, the story restarts from the paragraph being read, in the
         * new voice. ListenVoiceSettingsViewModel.kt waits for the save before calling this.
         */
        @MainThread
        fun restartWithCurrentSettings() {
            val current = story ?: return
            val loadedManifest = manifest ?: return
            val paragraph = ListenSegments.firstParagraph(loadedManifest.segments, currentSegment)
            val language = loadedManifest.language
            val voiceId = listenPreferences.current().voiceFor(language)
            val wasPlaying = playWhenReady
            startStory(
                current,
                startParagraph = paragraph,
                language = language,
                voiceId = voiceId,
                play = wasPlaying,
            )
        }

        /** Stops Listen and hides the mini player. */
        @MainThread
        fun close() {
            story?.let(::recordHistory)
            reportProgress()
            playedTime.reset()
            invalidateStory()
            story = null
            manifest = null
            timeline = ListenTimeline(emptyList())
            error = null
            queue = emptyList()
            upNext = emptyList()
            queueSource = null
            queueFollowsListOrder = false
            continueFromHash = null
            phase = ListenPhase.IDLE
            playWhenReady = false
            mutableIcon.value = null
            artworkPng = null
            exoPlayer?.release()
            exoPlayer = null
            publish()
            controllerFuture?.let { MediaController.releaseFuture(it) }
            controllerFuture = null
            context.stopService(Intent(context, ListenPlaybackService::class.java))
        }

        /**
         * PrefsRepo.kt stops Listen when the account changes (logout, login as, a new server), from any thread. The
         * story, manifest, usage and media notification all go, and progress not yet sent is dropped rather than
         * reported under whoever signs in next.
         */
        fun stopForAccountChange() {
            if (Looper.myLooper() == Looper.getMainLooper()) {
                resetForAccountChange()
            } else {
                Handler(Looper.getMainLooper()).post(::resetForAccountChange)
            }
        }

        @MainThread
        private fun resetForAccountChange() {
            playedTime.reset()
            // Without a manifest, close() records no History and reports nothing for the old account.
            manifest = null
            close()
            usage = null
            upNextQueue = emptyList()
            queuedStories = emptyList()
            upNextQueueLoaded = false
            publish()
        }

        /** ListenPlaybackService.kt sends what played so far as it stops or the app's task is swiped away. */
        @MainThread
        fun flushProgress() = reportProgress()

        /** Refreshes Up Next's read states, for Now Playing as it opens. */
        @MainThread
        fun refreshUpNext() {
            val current = story ?: return
            val expected = generation
            scope.launch {
                val next = withContext(Dispatchers.IO) { continueAfter(current) }
                if (expected != generation) return@launch
                upNext = next
                publish()
            }
        }

        // endregion

        // region Session

        fun sessionSnapshot(): ListenSessionSnapshot =
            ListenSessionSnapshot(
                story = story,
                next = nextAfterCurrent(),
                playWhenReady = playWhenReady,
                playbackState =
                    when (phase) {
                        ListenPhase.IDLE -> Player.STATE_IDLE
                        ListenPhase.LOADING, ListenPhase.BUFFERING -> Player.STATE_BUFFERING
                        ListenPhase.PREVIEW_ENDED, ListenPhase.ENDED -> Player.STATE_ENDED
                        ListenPhase.READY, ListenPhase.ERROR -> Player.STATE_READY
                    },
                durationMs = displayDurationMs(),
                speed = speed.toFloat(),
                artwork = artworkPng,
                discontinuity = discontinuity,
            )

        fun logicalPositionMs(): Long {
            if (manifest == null) return 0L
            val player = exoPlayer
            val offset =
                if (player != null && segmentOfItem(player.currentMediaItem) == currentSegment) {
                    player.currentPosition
                } else {
                    lastOffsetMs
                }
            return timeline.positionMs(currentSegment, offset).coerceAtMost(displayDurationMs())
        }

        fun logicalBufferedPositionMs(): Long {
            val player = exoPlayer ?: return logicalPositionMs()
            if (segmentOfItem(player.currentMediaItem) != currentSegment) return logicalPositionMs()
            return timeline
                .positionMs(
                    currentSegment,
                    player.bufferedPosition,
                ).coerceAtMost(displayDurationMs())
        }

        // endregion

        // region Story loading

        private fun startStory(
            target: ListenStory,
            startParagraph: Int,
            language: String?,
            voiceId: String?,
            play: Boolean = true,
        ) {
            val previous = story
            if (previous != null && previous.storyHash != target.storyHash) recordHistory(previous)
            // Switching stories, or restarting this one in a new voice or delivery, reports the old manifest.
            reportProgress()
            playedTime.reset()
            lastProgressReportAt = SystemClock.elapsedRealtime()
            invalidateStory()
            story = target
            if (queue.any { it.storyHash == target.storyHash }) continueFromHash = target.storyHash
            manifest = null
            timeline = ListenTimeline(emptyList())
            currentSegment = 0
            lastOffsetMs = 0L
            error = null
            phase = ListenPhase.LOADING
            playWhenReady = play
            upNext = emptyList()
            if (previous?.storyHash != target.storyHash) {
                mutableIcon.value = null
                artworkPng = null
                loadArtwork(target)
            }
            exoPlayer?.let {
                it.stop()
                it.clearMediaItems()
            }
            // A queued story leaves Up Next as it starts playing.
            if (ListenUpNextQueue.isQueued(upNextQueue, target.storyHash)) removeFromUpNext(target.storyHash)
            if (!upNextQueueLoaded) refreshUpNextQueue()
            ensureService()
            publish()
            refreshUpNext()

            val expected = generation
            launchForStory {
                val result =
                    listenApi.getManifest(
                        target.storyHash,
                        language = language,
                        voiceId = voiceId,
                    )
                if (expected != generation) return@launchForStory
                when (result) {
                    is ListenResult.Failure -> fail(result.error)
                    is ListenResult.Success -> {
                        applyManifest(result.value)
                        val segments = result.value.segments
                        if (segments.isEmpty()) {
                            fail(ListenError(ListenError.REASON_NO_TEXT, null, result.value.usage))
                            return@launchForStory
                        }
                        val startSegment =
                            if (startParagraph >
                                0
                            ) {
                                ListenSegments.segmentForResume(segments, startParagraph)
                            } else {
                                0
                            }
                        playSegment(startSegment, 0L)
                    }
                }
            }
        }

        private fun applyManifest(loaded: ListenManifest) {
            manifest = loaded
            timeline = ListenTimeline.fromSegments(loaded.segments)
            playedTime.jumped()
            usage = loaded.usage ?: usage
            segmentUrls.clear()
            segmentFailures.clear()
            playbackRetries.clear()
            publish()
        }

        /** Requests a segment's URL, then plays from it, replacing whatever ExoPlayer had queued. */
        private fun playSegment(
            segmentIndex: Int,
            offsetMs: Long,
        ) {
            val expected = generation
            val request = ++playRequest
            sampleProgress()
            playedTime.jumped()
            currentSegment = segmentIndex
            lastOffsetMs = offsetMs
            waitingForSegment = null
            phase = ListenPhase.BUFFERING
            publish()
            launchForStory {
                val url = resolveSegmentUrl(segmentIndex, showFailure = false)
                // Requests can finish out of order; only the newest one may load ExoPlayer or show a failure.
                if (expected != generation || request != playRequest) return@launchForStory
                if (url == null) {
                    segmentFailures[segmentIndex]?.let { failure ->
                        if (failure.reason == ListenError.REASON_PREVIEW_ENDED) finishPreview() else fail(failure)
                    }
                    return@launchForStory
                }
                val player = ensureExoPlayer()
                player.setMediaItem(mediaItem(segmentIndex, url), offsetMs)
                player.playbackParameters = PlaybackParameters(speed.toFloat())
                player.volume = previewVolume()
                player.prepare()
                player.playWhenReady = playWhenReady
                prefetch(segmentIndex + 1)
            }
        }

        /** Loads the current segment's URL again, for seeking into a segment that was streamed live. */
        private fun reloadSegment(
            segmentIndex: Int,
            offsetMs: Long,
        ) {
            val player = exoPlayer ?: return
            val cached = segmentUrls[segmentIndex]
            if (cached == null || !cached.isFresh()) {
                playSegment(segmentIndex, offsetMs)
                return
            }
            player.setMediaItem(mediaItem(segmentIndex, cached.url), offsetMs)
            player.prepare()
            player.playWhenReady = playWhenReady
            prefetch(segmentIndex + 1)
        }

        /** When segment i starts, segment i+1 is requested and queued behind it: never more than one ahead. */
        private fun prefetch(segmentIndex: Int) {
            val loadedManifest = manifest ?: return
            if (segmentIndex >= loadedManifest.segments.size) return
            if (segmentIndex in pendingSegments) return
            val player = exoPlayer ?: return
            if (segmentOfItem(nextItem(player)) == segmentIndex) return
            val expected = generation
            pendingSegments += segmentIndex
            launchForStory {
                val url = resolveSegmentUrl(segmentIndex, showFailure = false)
                pendingSegments -= segmentIndex
                if (expected != generation || url == null) return@launchForStory
                queueAfterCurrent(segmentIndex, url)
            }
        }

        private fun queueAfterCurrent(
            segmentIndex: Int,
            url: String,
        ) {
            val player = exoPlayer ?: return
            if (segmentOfItem(player.currentMediaItem) != segmentIndex - 1) return
            val current = player.currentMediaItemIndex
            if (player.mediaItemCount >
                current + 1
            ) {
                player.removeMediaItems(current + 1, player.mediaItemCount)
            }
            player.addMediaItem(mediaItem(segmentIndex, url))
            if (waitingForSegment == segmentIndex) {
                // The previous segment ended before this one's URL arrived.
                waitingForSegment = null
                player.seekTo(current + 1, 0L)
                player.prepare()
                player.playWhenReady = playWhenReady
            }
        }

        /**
         * Returns a playable URL for a segment, refreshing an expiring manifest and retrying a failed request
         * once. On failure it shows the error unless this was a quiet prefetch.
         */
        private suspend fun resolveSegmentUrl(
            segmentIndex: Int,
            showFailure: Boolean = true,
        ): String? {
            segmentUrls[segmentIndex]?.takeIf { it.isFresh() }?.let { return it.url }
            val expected = generation
            if (manifestExpiresSoon() && !refreshManifest()) return null
            var result = requestSegment(segmentIndex) ?: return null
            if (result is ListenResult.Failure &&
                result.error.reason == ListenError.REASON_MANIFEST_EXPIRED
            ) {
                if (!refreshManifest()) return null
                result = requestSegment(segmentIndex) ?: return null
            }
            if (result is ListenResult.Failure && !isTerminal(result.error)) {
                delay(SEGMENT_RETRY_DELAY_MS)
                if (expected != generation) return null
                result = requestSegment(segmentIndex) ?: return null
            }
            if (expected != generation) return null
            return when (result) {
                is ListenResult.Success -> {
                    val response = result.value
                    val url =
                        response.url
                            ?.takeIf {
                                it.isNotBlank()
                            }?.let(listenApi::resolveAudioUrl)
                    response.usage?.let { usage = it }
                    if (url == null) {
                        handleSegmentFailure(
                            segmentIndex,
                            ListenError(ListenError.REASON_PLAYBACK, null),
                            showFailure,
                        )
                        null
                    } else {
                        segmentFailures.remove(segmentIndex)
                        segmentUrls[segmentIndex] = CachedUrl(url, SystemClock.elapsedRealtime())
                        response.duration?.takeIf { it > 0.0 }?.let {
                            timeline =
                                timeline.withDuration(
                                    segmentIndex,
                                    ListenTimeline.secondsToMs(it),
                                    isKnown = true,
                                )
                        }
                        publish()
                        url
                    }
                }
                is ListenResult.Failure -> {
                    handleSegmentFailure(segmentIndex, result.error, showFailure)
                    null
                }
            }
        }

        private suspend fun requestSegment(segmentIndex: Int): ListenResult<ListenSegmentResponse>? {
            val manifestId = manifest?.manifestId ?: return null
            val expected = generation
            val result = listenApi.getSegment(manifestId, segmentIndex)
            return if (expected == generation) result else null
        }

        private fun handleSegmentFailure(
            segmentIndex: Int,
            failure: ListenError,
            showFailure: Boolean,
        ) {
            failure.usage?.let { usage = it }
            if (failure.reason == ListenError.REASON_PREVIEW_ENDED) {
                segmentFailures[segmentIndex] = failure
                if (showFailure) finishPreview()
                return
            }
            segmentFailures[segmentIndex] = failure
            if (showFailure || waitingForSegment == segmentIndex) fail(failure)
        }

        private fun manifestExpiresSoon(): Boolean {
            val expiresAt = manifest?.expiresAt ?: return false
            if (expiresAt <= 0.0) return false
            return System.currentTimeMillis() / 1000.0 > expiresAt - MANIFEST_REFRESH_MARGIN_SECONDS
        }

        /**
         * Fetches a new manifest for the story playing. When the new one splits the story the same way, playback
         * just carries on with its id; otherwise the story restarts at the paragraph being read.
         */
        private suspend fun refreshManifest(): Boolean {
            val current = story ?: return false
            val old = manifest ?: return false
            val expected = generation
            val result =
                listenApi.getManifest(
                    current.storyHash,
                    language = old.language,
                    voiceId = old.voice?.voiceId,
                )
            if (expected != generation) return false
            return when (result) {
                is ListenResult.Failure -> {
                    fail(result.error)
                    false
                }
                is ListenResult.Success -> {
                    val fresh = result.value
                    // What played so far belongs to the old manifest's id.
                    reportProgress()
                    if (fresh.segments.map { it.paragraphs } == old.segments.map { it.paragraphs }) {
                        manifest = fresh
                        usage = fresh.usage ?: usage
                        segmentUrls.clear()
                        true
                    } else {
                        val paragraph = ListenSegments.firstParagraph(old.segments, currentSegment)
                        applyManifest(fresh)
                        playSegment(ListenSegments.segmentForResume(fresh.segments, paragraph), 0L)
                        false
                    }
                }
            }
        }

        private fun isTerminal(failure: ListenError): Boolean =
            failure.reason in
                setOf(
                    ListenError.REASON_CAP_REACHED,
                    ListenError.REASON_SAMPLE_LIMIT,
                    ListenError.REASON_PREVIEW_ENDED,
                    ListenError.REASON_BAD_INDEX,
                    ListenError.REASON_UNAVAILABLE,
                    ListenError.REASON_NOT_FOUND,
                    ListenError.REASON_NO_TEXT,
                )

        private fun fail(failure: ListenError) {
            reportProgress()
            failure.usage?.let { usage = it }
            error = failure
            phase = ListenPhase.ERROR
            playWhenReady = false
            exoPlayer?.playWhenReady = false
            stopTicking()
            publish()
        }

        // endregion

        // region ExoPlayer

        private fun ensureExoPlayer(): ExoPlayer {
            exoPlayer?.let { return it }
            val http =
                DefaultHttpDataSource
                    .Factory()
                    .setUserAgent(listenApi.audioUserAgent)
                    .setAllowCrossProtocolRedirects(true)
                    .setConnectTimeoutMs(HTTP_TIMEOUT_MS)
                    .setReadTimeoutMs(HTTP_TIMEOUT_MS)
            // Cached segments come from S3 with a length, so constant bitrate seeking works inside them.
            val extractors = DefaultExtractorsFactory().setConstantBitrateSeekingEnabled(true)
            val player =
                ExoPlayer
                    .Builder(context)
                    .setMediaSourceFactory(
                        DefaultMediaSourceFactory(
                            DefaultDataSource.Factory(context, http),
                            extractors,
                        ),
                    ).setAudioAttributes(ListenSessionPlayer.AUDIO_ATTRIBUTES, true)
                    .setHandleAudioBecomingNoisy(true)
                    .setWakeMode(C.WAKE_MODE_NETWORK)
                    .build()
            player.addListener(exoListener)
            exoPlayer = player
            return player
        }

        private val exoListener =
            object : Player.Listener {
                override fun onMediaItemTransition(
                    mediaItem: MediaItem?,
                    reason: Int,
                ) {
                    val segment = segmentOfItem(mediaItem) ?: return
                    if (reason == Player.MEDIA_ITEM_TRANSITION_REASON_AUTO &&
                        segment == currentSegment + 1 &&
                        lastOffsetMs > 0L
                    ) {
                        // The segment that just finished played for exactly as long as it last reported.
                        timeline =
                            timeline.withDuration(currentSegment, lastOffsetMs, isKnown = true)
                    }
                    currentSegment = segment
                    lastOffsetMs = 0L
                    prefetch(segment + 1)
                    publish()
                }

                override fun onPlaybackStateChanged(playbackState: Int) {
                    val player = exoPlayer ?: return
                    when (playbackState) {
                        Player.STATE_BUFFERING ->
                            if (phase !=
                                ListenPhase.ERROR
                            ) {
                                phase = ListenPhase.BUFFERING
                            }
                        Player.STATE_READY -> {
                            if (phase != ListenPhase.ERROR &&
                                phase != ListenPhase.PREVIEW_ENDED
                            ) {
                                phase = ListenPhase.READY
                            }
                            if (player.isCurrentMediaItemSeekable &&
                                player.duration != C.TIME_UNSET
                            ) {
                                timeline =
                                    timeline.withDuration(
                                        currentSegment,
                                        player.duration,
                                        isKnown = true,
                                    )
                            }
                        }
                        Player.STATE_ENDED -> onSegmentsEnded()
                        Player.STATE_IDLE -> Unit
                    }
                    updateTicking()
                    publish()
                }

                override fun onIsPlayingChanged(isPlaying: Boolean) {
                    // Pausing, a stall or headphones coming out all report what played up to now.
                    if (!isPlaying) reportProgress()
                    updateTicking()
                    publish()
                }

                override fun onPlayWhenReadyChanged(
                    playWhenReady: Boolean,
                    reason: Int,
                ) {
                    // Audio focus loss and unplugged headphones pause ExoPlayer itself.
                    if (reason == Player.PLAY_WHEN_READY_CHANGE_REASON_AUDIO_FOCUS_LOSS ||
                        reason == Player.PLAY_WHEN_READY_CHANGE_REASON_AUDIO_BECOMING_NOISY
                    ) {
                        this@ListenManager.playWhenReady = playWhenReady
                        publish()
                    }
                }

                override fun onPlayerError(playbackError: PlaybackException) {
                    Log.w(
                        this@ListenManager.javaClass.name,
                        "Listen playback error in segment $currentSegment: ${playbackError.errorCodeName}",
                    )
                    val segment = currentSegment
                    val attempts = playbackRetries[segment] ?: 0
                    if (attempts >= 1) {
                        fail(ListenError(ListenError.REASON_PLAYBACK, null))
                        return
                    }
                    // One retry per failed segment with a fresh URL; asking again doesn't charge twice.
                    playbackRetries[segment] = attempts + 1
                    segmentUrls.remove(segment)
                    playSegment(segment, lastOffsetMs)
                }
            }

        private fun onSegmentsEnded() {
            val loadedManifest = manifest ?: return
            val player = exoPlayer ?: return
            sampleProgress()
            if (lastOffsetMs >
                0L
            ) {
                timeline = timeline.withDuration(currentSegment, lastOffsetMs, isKnown = true)
            }
            val next = currentSegment + 1
            when {
                loadedManifest.isPreview &&
                    (
                        next >= loadedManifest.segments.size ||
                            segmentFailures[next]?.reason == ListenError.REASON_PREVIEW_ENDED
                    ) ->
                    finishPreview()
                next < loadedManifest.segments.size -> {
                    val nextIndex = exoIndexOf(player, next)
                    if (nextIndex != null) {
                        player.seekTo(nextIndex, 0L)
                        player.prepare()
                    } else {
                        waitingForSegment = next
                        phase = ListenPhase.BUFFERING
                        val failure = segmentFailures[next]
                        if (failure != null) {
                            segmentFailures.remove(next)
                            playSegment(next, 0L)
                        } else {
                            prefetch(next)
                        }
                    }
                }
                else -> finishStory()
            }
        }

        private fun finishPreview() {
            reportProgress()
            phase = ListenPhase.PREVIEW_ENDED
            playWhenReady = false
            exoPlayer?.playWhenReady = false
            stopTicking()
            publish()
        }

        private fun finishStory() {
            val finished = story ?: return
            reportProgress(finished = true)
            phase = ListenPhase.ENDED
            playWhenReady = false
            exoPlayer?.playWhenReady = false
            stopTicking()
            publish()
            NBScope.launch(Dispatchers.IO) { storyRead.markFinished(finished) }
            // Up Next plays first, whether or not auto-continue is on; then the list's next story (ListenAutoContinue.kt).
            val queuedNext = ListenUpNextQueue.next(upNextQueue)
            if (queuedNext == null && !listenPreferences.current().autoContinue) return
            val expected = generation
            scope.launch {
                val next =
                    withContext(Dispatchers.IO) {
                        if (queuedNext != null) storyForQueueItem(queuedNext) else continueAfter(finished).firstOrNull()
                    } ?: return@launch
                if (expected != generation) return@launch
                startStory(next, startParagraph = 0, language = null, voiceId = null)
                mutableEvents.tryEmit(ListenEvent.Advanced(finished.storyHash, next))
            }
        }

        // region Up Next

        /**
         * What plays after this story: Up Next first, then auto-continue. The story playing is skipped, since it can
         * still be listed for a moment after it starts, and the lock screen's playlist can't hold it twice.
         */
        private fun nextAfterCurrent(): ListenStory? {
            val playing = story?.storyHash
            return queuedStories.firstOrNull { it.storyHash != playing } ?: upNext.firstOrNull { it.storyHash != playing }
        }

        /** The queue entry for a story: what apps/media_player stores for Listen (ListenUpNext.kt). */
        private fun queueItemFor(target: ListenStory): ListenQueueItem =
            ListenQueueItem(
                storyHash = target.storyHash,
                mediaUrl = ListenUpNextQueue.mediaUrl(target.storyHash),
                mediaType = ListenUpNextQueue.MEDIA_TYPE_LISTEN,
                title = target.title,
                feedId = target.feedId,
                imageUrl = target.faviconUrl,
            )

        /** The story that stopped playing goes to History with where it stopped, so it can be resumed. */
        private fun recordHistory(played: ListenStory) {
            if (manifest == null) return
            val item = queueItemFor(played)
            val positionSeconds = logicalPositionMs() / 1000.0
            val durationSeconds = displayDurationMs() / 1000.0
            NBScope.launch(Dispatchers.IO) { listenApi.addToHistory(item, positionSeconds, durationSeconds) }
        }

        /** Sends one Up Next change after the ones before it, then takes the server's queue once all have landed. */
        private fun sendQueueChange(request: suspend () -> ListenPlaybackState?) {
            pendingQueueChanges++
            scope.launch {
                val state = queueMutex.withLock { request() }
                pendingQueueChanges--
                if (pendingQueueChanges > 0) return@launch
                if (state != null) {
                    applyServerQueue(state.queue)
                } else {
                    // The change didn't take, so show what the server really has.
                    refreshUpNextQueue()
                }
            }
        }

        private fun applyServerQueue(serverQueue: List<ListenQueueItem>) {
            upNextQueueLoaded = true
            val playing = story?.storyHash
            if (playing != null && ListenUpNextQueue.isQueued(serverQueue, playing)) {
                // Queued elsewhere before it started here: it's playing, so it leaves Up Next.
                upNextQueue = serverQueue
                removeFromUpNext(playing)
                return
            }
            if (serverQueue == upNextQueue && queuedStories.size == ListenUpNextQueue.listenItems(serverQueue).size) return
            upNextQueue = serverQueue
            queueChanged()
        }

        /** Shows Up Next at once from what the queue carries, then fills in feed details from the database. */
        private fun queueChanged() {
            val items = ListenUpNextQueue.listenItems(upNextQueue)
            val known = queuedStories.associateBy { it.storyHash }
            queuedStories = items.map { known[it.storyHash] ?: storyFromQueueEntry(it, feed = null) }
            publish()
            val expected = upNextQueue
            scope.launch {
                val resolved = withContext(Dispatchers.IO) { items.map(::storyForQueueItem) }
                if (expected != upNextQueue) return@launch
                queuedStories = resolved
                upNext = upNext.filterNot { candidate -> resolved.any { it.storyHash == candidate.storyHash } }
                publish()
            }
        }

        /** Runs on Dispatchers.IO: the local copy of a queued story when this device has it, for marking it read. */
        private fun storyForQueueItem(item: ListenQueueItem): ListenStory =
            dbHelper.getStoryByHash(item.storyHash)?.let { storyFor(it) }
                ?: storyFromQueueEntry(item, feedUtils.getFeed(item.feedId))

        private fun storyFromQueueEntry(
            item: ListenQueueItem,
            feed: Feed?,
        ): ListenStory =
            ListenStory(
                storyHash = item.storyHash,
                title = UIUtils.fromHtml(item.title).toString(),
                feedId = item.feedId,
                feedTitle = feed?.title,
                faviconUrl = feed?.faviconUrl ?: item.imageUrl,
                feedColor = feed?.faviconColor,
                feedFade = feed?.faviconFade,
                story = null,
            )

        // endregion

        private fun updateTicking() {
            val player = exoPlayer
            if (player != null && player.isPlaying) startTicking() else stopTicking()
        }

        private fun startTicking() {
            if (tickJob?.isActive == true) return
            tickJob =
                scope.launch {
                    while (isActive) {
                        tick()
                        delay(TICK_MS)
                    }
                }
        }

        private fun stopTicking() {
            tickJob?.cancel()
            tickJob = null
        }

        private fun tick() {
            val player = exoPlayer ?: return
            if (segmentOfItem(player.currentMediaItem) != currentSegment) return
            lastOffsetMs = player.currentPosition
            sampleProgress()
            if (SystemClock.elapsedRealtime() - lastProgressReportAt >= PROGRESS_REPORT_MS) reportProgress()
            // A segment still streaming can run longer than its estimate; stretch the estimate to keep up.
            if (!timeline.known.getOrElse(currentSegment) { true } &&
                lastOffsetMs + ESTIMATE_SLACK_MS > timeline.durationMs(currentSegment)
            ) {
                timeline =
                    timeline.withDuration(
                        currentSegment,
                        lastOffsetMs + ESTIMATE_SLACK_MS,
                        isKnown = false,
                    )
            }
            if (manifest?.isPreview == true) {
                val position = logicalPositionMs()
                player.volume = previewVolume()
                if (ListenPreviewFade.isFinished(position, previewLimitMs())) {
                    finishPreview()
                    return
                }
            }
            publish()
        }

        private fun applySpeed(
            newSpeed: Double,
            save: Boolean,
        ) {
            val clamped = ListenSpeed.clamp(newSpeed)
            if (clamped == speed) return
            // Each report carries one speed, so what played at the old rate goes out first.
            reportProgress()
            speed = clamped
            // PlaybackParameters keeps the voice's pitch while the rate changes.
            exoPlayer?.playbackParameters = PlaybackParameters(clamped.toFloat())
            if (save) listenPreferences.saveSpeed(clamped)
            publish()
        }

        /** Counts the timeline position into ListenPlayedTime.kt while ExoPlayer is on the current segment. */
        private fun sampleProgress() {
            val player = exoPlayer ?: return
            if (manifest == null || segmentOfItem(player.currentMediaItem) != currentSegment) return
            playedTime.sample(logicalPositionMs(), SystemClock.elapsedRealtime(), speed)
        }

        /**
         * Tells POST /listen/progress how much of the story played since the last report, for usage stats. It's
         * fire and forget off the main thread, tried at most twice, and never shown to the reader.
         */
        private fun reportProgress(finished: Boolean = false) {
            val manifestId = manifest?.manifestId?.takeIf { it.isNotEmpty() } ?: return
            sampleProgress()
            lastProgressReportAt = SystemClock.elapsedRealtime()
            val playedMs = playedTime.take(finished) ?: return
            val report = ListenProgressReport(manifestId, playedMs, speed, finished)
            NBScope.launch(Dispatchers.IO) {
                if (listenApi.reportProgress(report)) return@launch
                delay(PROGRESS_RETRY_DELAY_MS)
                listenApi.reportProgress(report)
            }
        }

        private fun mediaItem(
            segmentIndex: Int,
            url: String,
        ): MediaItem =
            MediaItem
                .Builder()
                .setMediaId("$MEDIA_ID_PREFIX$segmentIndex:${++loadAttempt}")
                .setUri(url)
                .setMimeType("audio/mpeg")
                .build()

        private fun segmentOfItem(item: MediaItem?): Int? {
            val mediaId = item?.mediaId ?: return null
            if (!mediaId.startsWith(MEDIA_ID_PREFIX)) return null
            return mediaId.removePrefix(MEDIA_ID_PREFIX).substringBefore(':').toIntOrNull()
        }

        private fun exoIndexOf(
            player: ExoPlayer,
            segmentIndex: Int,
        ): Int? =
            (0 until player.mediaItemCount).firstOrNull {
                segmentOfItem(player.getMediaItemAt(it)) == segmentIndex
            }

        private fun nextItem(player: ExoPlayer): MediaItem? {
            val next = player.currentMediaItemIndex + 1
            return if (next < player.mediaItemCount) player.getMediaItemAt(next) else null
        }

        // endregion

        // region Helpers

        private fun previewLimitMs(): Long {
            val loadedManifest = manifest ?: return 0L
            if (!loadedManifest.isPreview) return 0L
            val seconds =
                loadedManifest.preview?.seconds ?: usage?.previewSeconds ?: DEFAULT_PREVIEW_SECONDS
            return ListenTimeline.secondsToMs(seconds)
        }

        private fun previewVolume(): Float {
            val limit = previewLimitMs()
            return if (limit > 0L) ListenPreviewFade.volume(logicalPositionMs(), limit) else 1f
        }

        /** Previews end at their limit even when their segments run a little longer. */
        private fun displayDurationMs(): Long {
            val total = timeline.totalMs
            val limit = previewLimitMs()
            return if (limit > 0L) minOf(total, limit) else total
        }

        private fun seekableDurationMs(): Long = (displayDurationMs() - 1L).coerceAtLeast(0L)

        /**
         * The stories auto-continue would play after this one (ListenAutoContinue.kt), with their feeds. Runs on a
         * background thread: it reads read states and feeds from the database.
         */
        private fun continueAfter(current: ListenStory): List<ListenStory> {
            val queued = upNextQueue
            val feeds = mutableMapOf<String?, Feed?>()
            return ListenAutoContinue
                .candidatesAfter(
                    stories = queue,
                    currentHash = current.storyHash,
                    continueFromHash = continueFromHash,
                    followsListOrder = queueFollowsListOrder,
                    limit = UP_NEXT_LIMIT,
                    // The database knows about reads since the queue was captured; the captured copy is the fallback.
                    isRead = { candidate -> dbHelper.isStoryRead(candidate.storyHash) ?: candidate.read },
                    isQueued = { hash -> ListenUpNextQueue.isQueued(queued, hash) },
                ).map { candidate ->
                    storyFor(
                        candidate,
                        feeds.getOrPut(candidate.feedId) {
                            feedUtils.getFeed(candidate.feedId)
                        },
                    )
                }
        }

        private fun storyFor(
            source: Story,
            feed: Feed? = feedUtils.getFeed(source.feedId),
        ): ListenStory =
            ListenStory(
                storyHash = source.storyHash,
                title = UIUtils.fromHtml(source.title.orEmpty()).toString(),
                feedId = source.feedId,
                feedTitle = feed?.title ?: source.extern_feedTitle,
                faviconUrl = feed?.faviconUrl ?: source.extern_faviconUrl,
                feedColor = feed?.faviconColor ?: source.extern_feedColor,
                feedFade = feed?.faviconFade ?: source.extern_feedFade,
                story = source,
            )

        private fun loadArtwork(target: ListenStory) {
            scope.launch {
                // Artwork is decoration: a feed icon that can't be loaded or drawn never stops playback.
                val result =
                    withContext(Dispatchers.IO) {
                        runCatching { ListenArtwork.render(context, target, iconCache) }
                            .onFailure { Log.w(this@ListenManager.javaClass.name, "Listen artwork failed: ${it.message}") }
                            .getOrNull()
                    } ?: return@launch
                if (story?.storyHash != target.storyHash) return@launch
                mutableIcon.value = result.icon
                artworkPng = result.artworkPng
                sessionPlayer.refresh()
            }
        }

        private fun ensureService() {
            if (story == null) return
            controllerFuture?.let { future ->
                val connected =
                    future.isDone && runCatching { future.get().isConnected }.getOrDefault(false)
                if (!future.isDone || connected) return
                MediaController.releaseFuture(future)
                controllerFuture = null
            }
            // Connecting a controller starts ListenPlaybackService.kt, which keeps playback alive in the background.
            val token =
                SessionToken(context, ComponentName(context, ListenPlaybackService::class.java))
            controllerFuture = MediaController.Builder(context, token).buildAsync()
        }

        private fun invalidateStory() {
            generation++
            storyJob.cancel()
            storyJob = SupervisorJob()
            pendingSegments.clear()
            segmentUrls.clear()
            segmentFailures.clear()
            playbackRetries.clear()
            waitingForSegment = null
            seekJob = null
            stopTicking()
        }

        private fun launchForStory(block: suspend CoroutineScope.() -> Unit): Job = scope.launch(storyJob, block = block)

        private fun publish() {
            val loadedManifest = manifest
            mutableState.value =
                ListenUiState(
                    story = story,
                    phase = phase,
                    playWhenReady = playWhenReady,
                    positionMs = logicalPositionMs(),
                    durationMs = displayDurationMs(),
                    segmentIndex = currentSegment,
                    paragraphs = loadedManifest?.paragraphs.orEmpty(),
                    segments = loadedManifest?.segments.orEmpty(),
                    voice = loadedManifest?.voice,
                    voiceFallback = loadedManifest?.voiceFallback == true,
                    language = loadedManifest?.language,
                    textSource = loadedManifest?.textSource,
                    isPreview = loadedManifest?.isPreview == true,
                    previewLimitMs = previewLimitMs(),
                    speed = speed,
                    error = error,
                    usage = usage,
                    upNext = upNext,
                    queued = queuedStories.filterNot { it.storyHash == story?.storyHash },
                    upNextSource = queueSource,
                )
            sessionPlayer.refresh()
        }

        // endregion

        private data class CachedUrl(
            val url: String,
            val fetchedAt: Long,
        ) {
            // Segment URLs are valid for about six hours; ListenManager.kt asks again well before that.
            fun isFresh(): Boolean = SystemClock.elapsedRealtime() - fetchedAt < URL_LIFETIME_MS
        }

        @EntryPoint
        @InstallIn(SingletonComponent::class)
        interface ListenEntryPoint {
            fun listenManager(): ListenManager
        }

        companion object {
            private const val MEDIA_ID_PREFIX = "listen-segment:"
            private const val TICK_MS = 200L
            private const val PROGRESS_REPORT_MS = 30_000L
            private const val PROGRESS_RETRY_DELAY_MS = 5_000L
            private const val SEEK_FROM_START_MS = 250L
            private const val SEEK_SETTLE_MS = 300L
            private const val ESTIMATE_SLACK_MS = 400L
            private const val SEGMENT_RETRY_DELAY_MS = 1_000L
            private const val MANIFEST_REFRESH_MARGIN_SECONDS = 60.0
            private const val URL_LIFETIME_MS = 5L * 60L * 60L * 1000L
            private const val HTTP_TIMEOUT_MS = 30_000
            private const val DEFAULT_PREVIEW_SECONDS = 30.0
            private const val UP_NEXT_LIMIT = 10

            /** For classes Hilt doesn't build, like StoryViewAdapter.kt's gesture handler. */
            @JvmStatic
            fun from(context: Context): ListenManager =
                EntryPointAccessors
                    .fromApplication(
                        context.applicationContext,
                        ListenEntryPoint::class.java,
                    ).listenManager()
        }
    }
