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
import kotlinx.coroutines.withTimeoutOrNull
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
    /** The story's audio file, like a podcast episode, playing instead of the story read aloud (ListenMedia.kt). */
    val media: ListenMedia? = null,
) {
    /** Up Next's identity for this entry, which tells a story read aloud from its own podcast episode. */
    val entryId: String
        get() = ListenUpNextQueue.entryId(storyHash, media?.url ?: ListenUpNextQueue.mediaUrl(storyHash))
}

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
    /** The web media player's skip intervals (ListenMediaSync.kt), for stories read aloud and podcasts alike. */
    val skipBackSeconds: Int = ListenMediaSettings.DEFAULT_SKIP_BACK_SECONDS,
    val skipForwardSeconds: Int = ListenMediaSettings.DEFAULT_SKIP_FORWARD_SECONDS,
) {
    /** Whether a story is queued to be read aloud; its podcast episode queued on its own doesn't count. */
    fun isQueued(storyHash: String?): Boolean = storyHash != null && queued.any { it.media == null && it.storyHash == storyHash }

    /** What the next button and the lock screen's next play: Up Next first, then auto-continue. */
    val nextStory: ListenStory?
        get() = queued.firstOrNull { it.entryId != story?.entryId } ?: upNext.firstOrNull { it.entryId != story?.entryId }

    val isActive: Boolean
        get() = story != null

    /** Whether a podcast episode or other audio file is playing rather than a story read aloud. */
    val isMedia: Boolean
        get() = story?.media != null

    /** Whether this audio file is the one loaded, for its card in the story (storyMedia.js). */
    fun isMediaLoaded(mediaUrl: String?): Boolean = mediaUrl != null && story?.media?.url == mediaUrl

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

    /** Whether Listen is reading this story aloud; its podcast episode playing doesn't count. */
    fun isStory(storyHash: String?): Boolean = storyHash != null && story?.storyHash == storyHash && story?.media == null
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
        private val audioMix: ListenAudioMix,
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

        // The Music section's boost past 100% and the focus Listen holds itself while playing over other audio.
        private val voiceBoost = ListenVoiceBoost()
        private var exoTakesAudioFocus = true
        private val audioFocus by lazy {
            ListenAudioFocus(context, onPause = { setPlayWhenReady(false) }, onResume = { setPlayWhenReady(true) })
        }
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

        // A podcast episode (ListenMedia.kt) plays its file straight through the same ExoPlayer, and ListenMediaSync.kt
        // keeps the web media player's state in step: where it is, the skip intervals and the podcast rate.
        private val mediaSync = ListenMediaSync(listenApi, NBScope, SystemClock::elapsedRealtime)

        // Where the episode starts, or stands while ExoPlayer doesn't hold it yet, and its length once ExoPlayer knows.
        private var episodeStartMs = 0L
        private var episodeDurationMs = 0L

        // Whether ExoPlayer was handed the episode, so stopping it has a position worth saving.
        private var episodeStarted = false

        // A seek before the episode loaded wins over the position the server remembered.
        private var episodePositionChosen = false

        // The episode's end already went to History; playing it again clears this.
        private var episodeRecorded = false
        private var episodeRetried = false

        init {
            scope.launch {
                // Up Next can change on the web or iOS while the app is away, so it's read again on return.
                ProcessLifecycleOwner.get().lifecycle.addObserver(
                    object : DefaultLifecycleObserver {
                        override fun onStart(owner: LifecycleOwner) {
                            if (story != null) refreshUpNextQueue()
                        }

                        // The app going away may be the last chance to save where an episode is.
                        override fun onStop(owner: LifecycleOwner) = saveEpisodePosition()
                    },
                )
            }
            scope.launch {
                listenPreferences.settings.collect { settings ->
                    // Speed changed from Settings or another device's sync. Podcasts keep their own rate.
                    if (story?.media == null && ListenSpeed.clamp(settings.speed) != speed) applySpeed(settings.speed, save = false)
                }
            }
            scope.launch {
                // The Music section changed playing over other audio, lowering the music, or the balance.
                audioMix.settings.collect { applyAudioMix() }
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
            if (this.story?.storyHash == story.storyHash && this.story?.media == null) {
                togglePlayPause()
                return
            }
            // Listen always plays now; the story or episode that was playing goes to History (startStory).
            val target = storyFor(story)
            queue = queueStories.ifEmpty { listOf(story) }
            queueSource = sourceName
            queueFollowsListOrder = followsListOrder
            startStory(target, startParagraph = 0, language = null, voiceId = null)
        }

        /**
         * Plays an audio file from a story, like a podcast episode, in place of whatever is playing; the file already
         * loaded toggles instead. It picks up where the web, iOS or this app left it (ListenMediaResume.kt).
         */
        @MainThread
        fun playMedia(
            source: Story,
            mediaUrl: String,
        ) {
            if (story?.media?.url == mediaUrl) {
                togglePlayPause()
                return
            }
            startStory(mediaStoryFor(source, mediaUrl), startParagraph = 0, language = null, voiceId = null)
        }

        /**
         * The web's Play Next and Play Last for an audio file (story_detail_view.js): first or last in Up Next, or
         * playing right away when nothing else is. Returns where it landed, 1 for first, or null when it plays now
         * or already is.
         */
        @MainThread
        fun queueMedia(
            source: Story,
            mediaUrl: String,
            playNext: Boolean,
        ): Int? {
            val target = mediaStoryFor(source, mediaUrl)
            if (story == null) {
                startStory(target, startParagraph = 0, language = null, voiceId = null)
                return null
            }
            if (story?.entryId == target.entryId) return null
            val item = queueItemFor(target)
            upNextQueue =
                if (playNext) ListenUpNextQueue.prepended(upNextQueue, item) else ListenUpNextQueue.appended(upNextQueue, item)
            val position = ListenUpNextQueue.positionOf(upNextQueue, item.entryId) ?: 1
            queueChanged()
            sendQueueChange { listenApi.addToUpNext(item, position = if (playNext) 0 else null) }
            return position
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
                if (play) player.volume = playerVolume()
                // While a seek settles, ExoPlayer still holds the old position; playSegment starts the new one.
                if (seekJob?.isActive != true) player.playWhenReady = play
            }
            ensureService()
            publish()
        }

        @MainThread
        fun seekTo(positionMs: Long) {
            if (story?.media != null) {
                seekEpisode(positionMs)
                return
            }
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
            exoPlayer?.volume = playerVolume()
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

        /** Skips back by the web media player's interval (skip_back_seconds), for stories and podcasts alike. */
        @MainThread
        fun skipBack() =
            seekTo(
                ListenSeek.target(
                    logicalPositionMs(),
                    -mediaSync.settings.skipBackMs,
                    skipRangeMs(),
                ),
            )

        @MainThread
        fun skipForward() =
            seekTo(
                ListenSeek.target(
                    logicalPositionMs(),
                    mediaSync.settings.skipForwardMs,
                    skipRangeMs(),
                ),
            )

        /** How far a skip may land; an episode whose length isn't known yet skips forward without a limit. */
        private fun skipRangeMs(): Long = if (story?.media != null && episodeDurationMs <= 0L) Long.MAX_VALUE else seekableDurationMs()

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

        /** Plays an entry from Up Next or the auto-continue list now, by entryId; a queued one leaves Up Next as it starts. */
        @MainThread
        fun playQueued(entryId: String) {
            val target =
                queuedStories.firstOrNull { it.entryId == entryId }
                    ?: upNext.firstOrNull { it.entryId == entryId }
                    ?: queue
                        .firstOrNull { ListenUpNextQueue.entryId(it.storyHash, ListenUpNextQueue.mediaUrl(it.storyHash)) == entryId }
                        ?.let(::storyFor)
                    ?: return
            startStory(target, startParagraph = 0, language = null, voiceId = null)
        }

        /** Adds a story to the end of Up Next and returns where it landed, 1 for first, for the confirmation. */
        @MainThread
        fun addToUpNext(source: Story): Int {
            val item = queueItemFor(storyFor(source))
            upNextQueue = ListenUpNextQueue.appended(upNextQueue, item)
            val position = ListenUpNextQueue.positionOf(upNextQueue, item.entryId) ?: 1
            queueChanged()
            sendQueueChange { listenApi.addToUpNext(item) }
            return position
        }

        /** Takes a story queued to be read aloud out of Up Next; its podcast episode, if queued, stays. */
        @MainThread
        fun removeFromUpNext(storyHash: String) {
            val item = ListenUpNextQueue.listenItems(upNextQueue).firstOrNull { it.storyHash == storyHash } ?: return
            removeQueued(item.entryId)
        }

        /** Takes any Up Next entry out, a story read aloud or a podcast episode, by its entryId. */
        @MainThread
        fun removeQueued(entryId: String) {
            val item = upNextQueue.firstOrNull { it.entryId == entryId } ?: return
            upNextQueue = ListenUpNextQueue.withoutEntry(upNextQueue, entryId)
            queueChanged()
            sendQueueChange { listenApi.removeFromUpNext(item) }
        }

        /** Moves an Up Next entry, counting positions as Up Next shows them; videos queued on the web stay put. */
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
                // The skip intervals and auto-play may have changed on the web.
                mediaSync.applyState(state)
                // A change made while this was on its way is newer than what came back.
                if (pendingQueueChanges > 0) {
                    publish()
                    return@launch
                }
                applyServerQueue(state.queue)
                publish()
            }
        }

        @MainThread
        fun retry() {
            val current = story ?: return
            error = null
            if (current.media != null) {
                retryEpisode(current.media)
                return
            }
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

        /** Stops Listen and hides the mini player; what was playing stays the server's current item, paused. */
        @MainThread
        fun close() {
            saveListenCurrent(isPlaying = false)
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
            voiceBoost.release()
            publish()
            // ListenManager.kt: an interruption can still hold focus or a call watch; closing gives both back.
            audioFocus.release()
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
            // Without a manifest, close() records no History and reports nothing for the old account, and an episode
            // that never started saves no position under it.
            manifest = null
            episodeStarted = false
            close()
            mediaSync.reset()
            usage = null
            upNextQueue = emptyList()
            queuedStories = emptyList()
            upNextQueueLoaded = false
            publish()
        }

        /** ListenPlaybackService.kt sends what played so far, and where an episode is, as it stops or the app's task is swiped away. */
        @MainThread
        fun flushProgress() {
            reportProgress()
            saveEpisodePosition()
        }

        /** Refreshes Up Next's read states, for Now Playing as it opens. */
        @MainThread
        fun refreshUpNext() {
            val current = story ?: return
            // A podcast episode continues only through Up Next, never down the story list.
            if (current.media != null) {
                upNext = emptyList()
                publish()
                return
            }
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
                skipBackMs = mediaSync.settings.skipBackMs,
                skipForwardMs = mediaSync.settings.skipForwardMs,
            )

        fun logicalPositionMs(): Long {
            if (story?.media != null) return episodePositionMs()
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
            if (story?.media != null) return if (isEpisodeItem(player.currentMediaItem)) player.bufferedPosition else logicalPositionMs()
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
            // Switching between a story read aloud and its own podcast episode counts as switching too.
            if (previous != null && previous.entryId != target.entryId) recordHistory(previous)
            // Switching stories, or restarting this one in a new voice or delivery, reports the old manifest.
            reportProgress()
            playedTime.reset()
            lastProgressReportAt = SystemClock.elapsedRealtime()
            invalidateStory()
            story = target
            if (target.media == null && queue.any { it.storyHash == target.storyHash }) continueFromHash = target.storyHash
            episodeStartMs = 0L
            episodeDurationMs = 0L
            episodeStarted = false
            episodePositionChosen = false
            episodeRecorded = false
            episodeRetried = false
            // Podcasts play at their own rate, the web's media_playback_rate, and stories read aloud at Listen's.
            speed = if (target.media != null) mediaSync.speed else listenPreferences.current().speed
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
            applyAudioMix()
            // A queued story or episode leaves Up Next as it starts playing.
            if (ListenUpNextQueue.containsEntry(upNextQueue, target.entryId)) removeQueued(target.entryId)
            // An episode reads the playback state itself, for where to resume (loadEpisode).
            if (!upNextQueueLoaded && target.media == null) refreshUpNextQueue()
            ensureService()
            publish()
            refreshUpNext()
            if (target.media != null) {
                loadEpisode(target, target.media)
                return
            }

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
                        saveListenCurrent(isPlaying = playWhenReady)
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
                player.volume = playerVolume()
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
                    ).setAudioAttributes(ListenSessionPlayer.AUDIO_ATTRIBUTES, takesAudioFocus.also { exoTakesAudioFocus = it })
                    .setHandleAudioBecomingNoisy(true)
                    .setWakeMode(C.WAKE_MODE_NETWORK)
                    .build()
            player.addListener(exoListener)
            exoPlayer = player
            voiceBoost.attach(player.audioSessionId)
            voiceBoost.setGain(ListenAudioMixMath.boostMillibels(playbackAudioMix.effectiveVoiceVolume))
            return player
        }

        /**
         * Whether Listen's players take audio focus, pausing other apps. Not while Listen plays over other audio
         * (ListenAudioMix.kt), where ListenAudioFocus.kt handles focus instead; the voice preview in
         * ListenVoiceSettingsViewModel.kt follows the same rule.
         */
        private val playbackAudioMix: ListenAudioMixSettings
            get() = audioMix.current().forPlayback(isMedia = story?.media != null)

        /** ListenVoiceSettingsViewModel.kt samples always follow narration preferences, even with a podcast loaded. */
        val previewTakesAudioFocus: Boolean
            get() = audioMix.current().focusMode == ListenFocusMode.EXCLUSIVE

        val takesAudioFocus: Boolean
            get() = playbackAudioMix.focusMode == ListenFocusMode.EXCLUSIVE

        /** The Music section changed: ExoPlayer's focus handling, the voice's volume and its boost follow. */
        private fun applyAudioMix() {
            exoPlayer?.let { player ->
                // The balance slider saves on every step, but focus handling only changes with Play over other audio.
                if (takesAudioFocus != exoTakesAudioFocus) {
                    exoTakesAudioFocus = takesAudioFocus
                    player.setAudioAttributes(ListenSessionPlayer.AUDIO_ATTRIBUTES, takesAudioFocus)
                }
                player.volume = playerVolume()
            }
            voiceBoost.setGain(ListenAudioMixMath.boostMillibels(playbackAudioMix.effectiveVoiceVolume))
            updateAudioFocus()
        }

        /** The preview fade times the balance's share of the voice volume (the boost does the rest). */
        private fun playerVolume(): Float = previewVolume() * ListenAudioMixMath.playerVolume(playbackAudioMix.effectiveVoiceVolume)

        /** While Listen plays over other audio, ListenAudioFocus.kt lowers that audio only while the voice plays. */
        private fun updateAudioFocus() {
            val speaking =
                story != null &&
                    playWhenReady &&
                    phase != ListenPhase.IDLE &&
                    phase != ListenPhase.ENDED &&
                    phase != ListenPhase.PREVIEW_ENDED &&
                    phase != ListenPhase.ERROR
            audioFocus.update(
                mode = playbackAudioMix.focusMode,
                speaking = speaking,
                abandonDelayMs = if (phase == ListenPhase.ENDED) AUTO_CONTINUE_FOCUS_GRACE_MS else 0L,
            )
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
                            if (isEpisodeItem(player.currentMediaItem)) {
                                if (player.duration != C.TIME_UNSET && player.duration > 0L) episodeDurationMs = player.duration
                            } else if (player.isCurrentMediaItemSeekable &&
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
                        Player.STATE_ENDED -> if (isEpisodeItem(player.currentMediaItem)) finishEpisode() else onSegmentsEnded()
                        Player.STATE_IDLE -> Unit
                    }
                    updateTicking()
                    publish()
                }

                override fun onAudioSessionIdChanged(audioSessionId: Int) {
                    voiceBoost.attach(audioSessionId)
                }

                override fun onIsPlayingChanged(isPlaying: Boolean) {
                    // Pausing, a stall or headphones coming out all report what played up to now.
                    if (!isPlaying) reportProgress()
                    val player = exoPlayer
                    val playing = story
                    // A pause, whether from a button, audio focus or headphones; a stall or a seek keeps playWhenReady.
                    val paused = !isPlaying && !this@ListenManager.playWhenReady
                    if (player != null && playing?.media != null && episodeStarted && isEpisodeItem(player.currentMediaItem)) {
                        if (isPlaying) {
                            // Played again after it finished, so its end can go to History again.
                            episodeRecorded = false
                        } else if (paused) {
                            mediaSync.paused(queueItemFor(playing), player.currentPosition, episodeDurationMs)
                        }
                    } else if (paused && phase != ListenPhase.ENDED) {
                        saveListenCurrent(isPlaying = false)
                    }
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
                    if (story?.media != null) {
                        onEpisodeError(playbackError)
                        return
                    }
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
            advanceAfter(finished)
        }

        /**
         * What plays when a story or episode ends: Up Next first, a story read aloud or a podcast alike, when the web's
         * auto-play (auto_play_next) is on; then, after a story read aloud, the list's next story (ListenAutoContinue.kt).
         */
        private fun advanceAfter(finished: ListenStory) {
            val queuedNext = ListenUpNextQueue.next(upNextQueue, mediaSync.settings.autoPlayNext)
            val continuesList = finished.media == null && listenPreferences.current().autoContinue
            if (queuedNext == null && !continuesList) return
            val expected = generation
            scope.launch {
                val next =
                    withContext(Dispatchers.IO) {
                        if (queuedNext != null) storyForQueueItem(queuedNext) else continueAfter(finished).firstOrNull()
                    } ?: return@launch
                if (expected != generation) return@launch
                startStory(next, startParagraph = 0, language = null, voiceId = null)
                // A reader following a story read aloud turns to the next one; podcasts don't turn pages.
                if (finished.media == null && next.media == null) mutableEvents.tryEmit(ListenEvent.Advanced(finished.storyHash, next))
            }
        }

        // region Podcast episodes

        /**
         * Starts a podcast episode: playback_state says where it was left (ListenMediaResume.kt), then ExoPlayer streams
         * the file from there and ListenMediaSync.kt makes it the server's current item. Without an answer in time it
         * starts from the top rather than keep the listener waiting.
         */
        private fun loadEpisode(
            target: ListenStory,
            media: ListenMedia,
        ) {
            val expected = generation
            launchForStory {
                val state = withTimeoutOrNull(RESUME_LOOKUP_TIMEOUT_MS) { listenApi.getPlaybackState() }
                if (expected != generation) return@launchForStory
                if (state != null) {
                    mediaSync.applyState(state)
                    mediaSync.keepReplacedInHistory(state.current, queueItemFor(target))
                    if (pendingQueueChanges == 0) applyServerQueue(state.queue)
                }
                speed = mediaSync.speed
                if (!episodePositionChosen) {
                    episodeStartMs = ListenMediaResume.startPositionMs(state, target.storyHash, media.url, media.type)
                }
                val player = ensureExoPlayer()
                player.setMediaItem(episodeItem(media), episodeStartMs)
                player.playbackParameters = PlaybackParameters(speed.toFloat())
                player.volume = 1f
                player.prepare()
                player.playWhenReady = playWhenReady
                episodeStarted = true
                phase = ListenPhase.BUFFERING
                discontinuity++
                mediaSync.started(queueItemFor(target), episodeStartMs, episodeDurationMs, isPlaying = playWhenReady)
                publish()
            }
        }

        private fun seekEpisode(positionMs: Long) {
            val target = if (episodeDurationMs > 0L) positionMs.coerceIn(0L, episodeDurationMs - 1L) else positionMs.coerceAtLeast(0L)
            discontinuity++
            val player = exoPlayer
            val playing = story
            if (playing != null && episodeStarted && player != null && isEpisodeItem(player.currentMediaItem)) {
                player.seekTo(target)
                mediaSync.seeked(queueItemFor(playing), target, episodeDurationMs, isPlaying = playWhenReady)
            } else {
                // Not loaded yet: it starts here instead of where the server left it.
                episodeStartMs = target
                episodePositionChosen = true
            }
            publish()
        }

        /** Retry after a failed episode: the same file again from where it stopped. */
        private fun retryEpisode(media: ListenMedia) {
            if (!episodeStarted) {
                story?.let { startStory(it, startParagraph = 0, language = null, voiceId = null) }
                return
            }
            episodeRetried = false
            playWhenReady = true
            reloadEpisode(media)
        }

        private fun reloadEpisode(media: ListenMedia) {
            val player = ensureExoPlayer()
            val position = episodePositionMs()
            episodeStartMs = position
            phase = ListenPhase.BUFFERING
            player.setMediaItem(episodeItem(media), position)
            player.playbackParameters = PlaybackParameters(speed.toFloat())
            player.prepare()
            player.playWhenReady = playWhenReady
            publish()
        }

        /** A stream that drops gets one more try from where it was; a second failure shows Retry. */
        private fun onEpisodeError(playbackError: PlaybackException) {
            val media = story?.media ?: return
            Log.w(this.javaClass.name, "Episode playback error: ${playbackError.errorCodeName}")
            if (episodeRetried) {
                fail(ListenError(ListenError.REASON_PLAYBACK, null))
                return
            }
            episodeRetried = true
            reloadEpisode(media)
        }

        private fun tickEpisode() {
            val playing = story ?: return
            val player = exoPlayer ?: return
            if (!isEpisodeItem(player.currentMediaItem)) return
            if (player.duration != C.TIME_UNSET && player.duration > 0L) episodeDurationMs = player.duration
            mediaSync.playing(queueItemFor(playing), player.currentPosition, episodeDurationMs)
            publish()
        }

        /** The episode played to its end: it goes to History, and Up Next plays when auto-play is on. */
        private fun finishEpisode() {
            val finished = story ?: return
            if (episodeDurationMs <= 0L) episodeDurationMs = episodePositionMs()
            phase = ListenPhase.ENDED
            playWhenReady = false
            exoPlayer?.playWhenReady = false
            stopTicking()
            publish()
            if (!episodeRecorded) {
                mediaSync.finished(queueItemFor(finished), episodeDurationMs)
                episodeRecorded = true
            }
            advanceAfter(finished)
        }

        /**
         * A story read aloud is the server's current item too, as on the web and iOS: saved as it starts and pauses,
         * with where it is in Listen's audio.
         */
        private fun saveListenCurrent(isPlaying: Boolean) {
            val playing = story ?: return
            if (playing.media != null || manifest == null) return
            mediaSync.listening(queueItemFor(playing), logicalPositionMs(), displayDurationMs(), isPlaying)
        }

        /** Saves where an episode is now, whatever the throttle: the app going to the background, or being swiped away. */
        private fun saveEpisodePosition() {
            val playing = story ?: return
            if (playing.media == null || !episodeStarted || episodeRecorded) return
            mediaSync.saveNow(queueItemFor(playing), episodePositionMs(), episodeDurationMs, isPlaying = exoPlayer?.isPlaying == true)
        }

        private fun episodePositionMs(): Long {
            val player = exoPlayer
            if (!episodeStarted || player == null || !isEpisodeItem(player.currentMediaItem)) return episodeStartMs
            return player.currentPosition
        }

        private fun episodeItem(media: ListenMedia): MediaItem =
            MediaItem
                .Builder()
                .setMediaId("$EPISODE_ID_PREFIX${++loadAttempt}")
                .setUri(media.streamUrl)
                .build()

        private fun isEpisodeItem(item: MediaItem?): Boolean = item?.mediaId?.startsWith(EPISODE_ID_PREFIX) == true

        // endregion

        // region Up Next

        /**
         * What plays after this story: Up Next first, then auto-continue. The story playing is skipped, since it can
         * still be listed for a moment after it starts, and the lock screen's playlist can't hold it twice.
         */
        private fun nextAfterCurrent(): ListenStory? {
            val playing = story?.entryId
            val queued = queuedStories.firstOrNull { it.entryId != playing }
            // A podcast episode continues only through Up Next.
            if (story?.media != null) return queued
            return queued ?: upNext.firstOrNull { it.entryId != playing }
        }

        /**
         * The queue entry for a story or episode: what apps/media_player stores (ListenUpNext.kt). Like the web, an
         * episode carries the story's first image and a story read aloud its feed's icon.
         */
        private fun queueItemFor(target: ListenStory): ListenQueueItem {
            val media = target.media
            return ListenQueueItem(
                storyHash = target.storyHash,
                mediaUrl = media?.url ?: ListenUpNextQueue.mediaUrl(target.storyHash),
                mediaType = media?.type ?: ListenUpNextQueue.MEDIA_TYPE_LISTEN,
                title = target.title,
                feedId = target.feedId,
                imageUrl = if (media != null) media.imageUrl else target.faviconUrl,
            )
        }

        /** The story or episode that stopped playing goes to History with where it stopped, so it can be resumed. */
        private fun recordHistory(played: ListenStory) {
            if (played.media != null) {
                // An episode also saves where it stopped as the server's current item (ListenMediaSync.kt).
                if (episodeStarted && !episodeRecorded) {
                    mediaSync.stopped(queueItemFor(played), episodePositionMs(), episodeDurationMs)
                    episodeRecorded = true
                }
                return
            }
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
            val playing = story?.entryId
            if (playing != null && ListenUpNextQueue.containsEntry(serverQueue, playing)) {
                // Queued elsewhere before it started here: it's playing, so it leaves Up Next.
                upNextQueue = serverQueue
                removeQueued(playing)
                return
            }
            if (serverQueue == upNextQueue && queuedStories.size == ListenUpNextQueue.playableItems(serverQueue).size) return
            upNextQueue = serverQueue
            queueChanged()
        }

        /** Shows Up Next at once from what the queue carries, then fills in feed details from the database. */
        private fun queueChanged() {
            val items = ListenUpNextQueue.playableItems(upNextQueue)
            val known = queuedStories.associateBy { it.entryId }
            queuedStories = items.map { known[it.entryId] ?: storyFromQueueEntry(it, feed = null) }
            publish()
            val expected = upNextQueue
            scope.launch {
                val resolved = withContext(Dispatchers.IO) { items.map(::storyForQueueItem) }
                if (expected != upNextQueue) return@launch
                queuedStories = resolved
                upNext = upNext.filterNot { candidate -> resolved.any { it.entryId == candidate.entryId } }
                publish()
            }
        }

        /** Runs on Dispatchers.IO: the local copy of a queued story when this device has it, for marking it read. */
        private fun storyForQueueItem(item: ListenQueueItem): ListenStory =
            dbHelper.getStoryByHash(item.storyHash)?.let { storyFor(it).copy(media = mediaOf(item)) }
                ?: storyFromQueueEntry(item, feedUtils.getFeed(item.feedId))

        /** A queued podcast episode's file; null for a story queued to be read aloud. */
        private fun mediaOf(item: ListenQueueItem): ListenMedia? =
            if (item.isListen) null else ListenMedia(url = item.mediaUrl, type = item.mediaType, imageUrl = item.imageUrl)

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
                media = mediaOf(item),
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
            if (story?.media != null) {
                tickEpisode()
                return
            }
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
                player.volume = playerVolume()
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
            val playing = story
            when {
                !save -> Unit
                // A podcast's rate is the web's media_playback_rate, saved with the episode (ListenMediaSync.kt).
                playing?.media != null ->
                    mediaSync.changeSpeed(
                        clamped,
                        queueItemFor(playing).takeIf { episodeStarted },
                        episodePositionMs(),
                        episodeDurationMs,
                        isPlaying = playWhenReady,
                    )
                else -> listenPreferences.saveSpeed(clamped)
            }
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
            if (story?.media != null) return episodeDurationMs
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

        /** A story's audio file as a ListenStory: the story's title and feed, playing the file. */
        private fun mediaStoryFor(
            source: Story,
            mediaUrl: String,
        ): ListenStory = storyFor(source).copy(media = ListenMedia(url = mediaUrl, imageUrl = source.imageUrls?.firstOrNull()))

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
                    queued = queuedStories.filterNot { it.entryId == story?.entryId },
                    upNextSource = queueSource,
                    skipBackSeconds = mediaSync.settings.skipBackSeconds,
                    skipForwardSeconds = mediaSync.settings.skipForwardSeconds,
                )
            sessionPlayer.refresh()
            updateAudioFocus()
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
            private const val EPISODE_ID_PREFIX = "listen-episode:"

            // How long an episode waits for playback_state to say where to resume before starting from the top.
            private const val RESUME_LOOKUP_TIMEOUT_MS = 4_000L
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

            // Auto-continue starts the next story within a moment, so the other app's music stays lowered between.
            private const val AUTO_CONTINUE_FOCUS_GRACE_MS = 2_000L

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
