package com.newsblur.service

import android.content.Context
import com.newsblur.R
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.util.AppConstants
import com.newsblur.util.FeedSet
import com.newsblur.util.Log
import com.newsblur.util.ReadingAction
import kotlinx.coroutines.flow.MutableStateFlow
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.concurrent.Volatile

/**
 * Holds all SyncService flags, containers, and metrics previously in the companion object.
 */
interface SyncServiceState {
    /**
     * The time of the last hard API failure we encountered. Used to implement back-off so that the sync
     * service doesn't spin in the background chewing up battery when the API is unavailable.
     */
    var lastApiFailure: Long
    var lastActionCount: Int

    var pendingFeed: FeedSet?
    var pendingFeedTarget: Int

    /**
     * Feed to reset to zero-state, so it is fetched fresh, presumably with new filters.
     */
    var resetFeed: FeedSet?

    var doFeedsFolders: Boolean
    var doFlushRecounts: Boolean
    var authFails: Int

    /**
     * Feed sets that the API has said to have no more pages left.
     */
    val exhaustedFeeds: Set<FeedSet>

    /**
     * Actions that may need to be double-checked locally due to overlapping API calls.
     */
    val followupActions: List<ReadingAction>

    /**
     * The number of pages we have collected for the given feed set.
     */
    val feedPagesSeen: Map<FeedSet, Int>

    /**
     * The number of stories we have collected for the given feed set.
     */
    val feedStoriesSeen: Map<FeedSet, Int>

    /**
     * Feed IDs (API type) that have been acted upon and need a double-check for counts.
     */
    val recountCandidates: Set<FeedSet>

    /**
     * The last feed set that was actually fetched from the API.
     */
    var lastFeedSet: FeedSet?

    var workaroundReadStoryTimestamp: Long
    var workaroundGlobalSharedStoryTimestamp: Long

    val pendingFeedMutex: Any
    val resetFeedMutex: Any

    fun forceFeedsFolders()

    fun flushRecounts()

    fun addRecountCandidate(fs: FeedSet?)

    fun addRecountCandidates(impactedFeeds: Set<FeedSet>)

    fun resetFetchState(fs: FeedSet?)

    fun resetReadingSession(dbHelper: BlurDatabaseHelper) // TODO suspend

    fun isFeedSetExhausted(fs: FeedSet?): Boolean

    fun isFeedSetSyncing(fs: FeedSet?): Boolean

    fun isFeedSetStoriesFresh(fs: FeedSet?): Boolean

    fun getPendingInfo(): String

    fun getSyncStatusMessage(
        context: Context,
        brief: Boolean,
    ): String?

    fun requestMoreForFeed(
        fs: FeedSet,
        desiredStoryCount: Int,
        callerSeen: Int?,
    ): Boolean

    /**
     * Resets any internal temp vars or queues. Called when switching accounts.
     */
    fun clearState()

    fun clearRecountCandidates()

    fun clearSeenFeedStories()

    fun removeFeedStoriesSeen(fs: FeedSet)

    fun addFeedStoriesSeen(
        fs: FeedSet,
        count: Int,
    )

    fun clearSeenFeedPages()

    fun removeFeedPagesSeen(fs: FeedSet)

    fun addFeedPagesSeen(
        fs: FeedSet,
        count: Int,
    )

    fun clearExhaustedFeeds()

    fun removeFeedSetExhausted(fs: FeedSet)

    fun addFeedSetExhausted(fs: FeedSet)

    fun clearFollowupActions()

    fun addFollowupAction(ra: ReadingAction)

    fun setServiceState(state: ServiceState)

    fun isFeedFolderSyncRunning(): Boolean

    fun isHousekeepingRunning(): Boolean

    fun isFeedCountSyncRunning(): Boolean
}

@Singleton
class DefaultSyncServiceState
    @Inject
    constructor() : SyncServiceState {
        private val serviceState = MutableStateFlow<ServiceState>(ServiceState.Idle)

        override var lastApiFailure: Long = 0L
        override var lastActionCount: Int = 0

        override var pendingFeed: FeedSet? = null
        override var pendingFeedTarget: Int = 0

        @Volatile
        override var resetFeed: FeedSet? = null

        @Volatile
        override var doFeedsFolders: Boolean = false

        @Volatile
        override var doFlushRecounts: Boolean = false

        @Volatile
        override var authFails: Int = 0

        private val _exhaustedFeeds = mutableSetOf<FeedSet>()
        private val _feedPagesSeen = mutableMapOf<FeedSet, Int>()
        private val _feedStoriesSeen = mutableMapOf<FeedSet, Int>()
        private val _recountCandidates = mutableSetOf<FeedSet>()
        private val _followupActions = mutableListOf<ReadingAction>()

        override val exhaustedFeeds: Set<FeedSet> get() = _exhaustedFeeds
        override val feedPagesSeen: Map<FeedSet, Int> get() = _feedPagesSeen
        override val feedStoriesSeen: Map<FeedSet, Int> get() = _feedStoriesSeen
        override val recountCandidates: Set<FeedSet> get() = _recountCandidates
        override val followupActions: List<ReadingAction> get() = _followupActions

        override var lastFeedSet: FeedSet? = null

        override var workaroundReadStoryTimestamp: Long = 0L
        override var workaroundGlobalSharedStoryTimestamp: Long = 0L

        override val pendingFeedMutex: Any = Any()
        override val resetFeedMutex: Any = Any()

        override fun setServiceState(state: ServiceState) {
            serviceState.value = state
        }

        /**
         * Force a refresh of feed/folder data on the next sync
         * even if enough time hasn't passed for an auto sync.
         */
        override fun forceFeedsFolders() {
            doFeedsFolders = true
        }

        override fun flushRecounts() {
            doFlushRecounts = true
        }

        override fun addRecountCandidate(fs: FeedSet?) {
            if (fs == null) return
            // if this is a special feedset (read, saved, global shared, etc) that doesn't represent a
            // countable set of stories, don't bother recounting it
            if (fs.getFlatFeedIds().isEmpty()) return
            _recountCandidates.add(fs)
        }

        override fun resetFetchState(fs: FeedSet?) {
            synchronized(resetFeedMutex) {
                Log.d(SyncServiceState::class.java.name, "requesting feed fetch state reset")
                resetFeed = fs
            }
        }

        override fun addFollowupAction(ra: ReadingAction) {
            _followupActions.add(ra)
        }

        override fun clearFollowupActions() {
            _followupActions.clear()
        }

        override fun isFeedSetExhausted(fs: FeedSet?) = fs != null && _exhaustedFeeds.contains(fs)

        override fun isFeedSetSyncing(fs: FeedSet?) = fs == pendingFeed

        override fun isFeedSetStoriesFresh(fs: FeedSet?) = (_feedStoriesSeen[fs] ?: 0) >= 1

        override fun getPendingInfo(): String =
            StringBuilder()
                .apply {
                    append(" pre:").append(lastActionCount)
                    append(" post:").append(_followupActions.size)
                }.toString()

        override fun getSyncStatusMessage(
            context: Context,
            brief: Boolean,
        ): String? =
            when (val state = serviceState.value) {
                is ServiceState.Housekeeping -> context.resources.getString(R.string.sync_status_housekeeping)
                is ServiceState.FolderFeedSync -> context.resources.getString(R.string.sync_status_ffsync)
                is ServiceState.CleanupSync -> context.resources.getString(R.string.sync_status_cleanup)
                is ServiceState.StarredSync -> context.resources.getString(R.string.sync_status_starred)
                else -> {
                    if (brief && !AppConstants.VERBOSE_LOG) {
                        null
                    } else {
                        when (state) {
                            is ServiceState.ActionsSync ->
                                String.format(
                                    context.resources.getString(R.string.sync_status_actions),
                                    lastActionCount,
                                )

                            is ServiceState.RecountsSync -> context.resources.getString(R.string.sync_status_recounts)
                            is ServiceState.StorySync -> context.resources.getString(R.string.sync_status_stories)
                            is ServiceState.UnreadsSync ->
                                takeIf { UnreadsSubService.pendingCount.isNotBlank() }?.let {
                                    String.format(context.resources.getString(R.string.sync_status_unreads), UnreadsSubService.pendingCount)
                                }

                            is ServiceState.ImagePrefetchSync ->
                                takeIf { ImagePrefetchSubService.pendingCount > 0 }?.let {
                                    String.format(
                                        context.resources.getString(R.string.sync_status_images),
                                        ImagePrefetchSubService.pendingCount,
                                    )
                                }

                            else -> null
                        }
                    }
                }
            }

        override fun requestMoreForFeed(
            fs: FeedSet,
            desiredStoryCount: Int,
            callerSeen: Int?,
        ): Boolean {
            synchronized(pendingFeedMutex) {
                if (exhaustedFeeds.contains(fs) && (fs == lastFeedSet && (callerSeen != null))) {
                    android.util.Log.d(SyncServiceState::class.java.name, "rejecting request for feedset that is exhausted")
                    return false
                }
                var alreadyPending = 0
                if (fs == pendingFeed) alreadyPending = pendingFeedTarget
                var alreadySeen = feedStoriesSeen[fs]
                if (alreadySeen == null) alreadySeen = 0
                if ((callerSeen != null) && (callerSeen < alreadySeen)) {
                    // the caller is probably filtering and thinks they have fewer than we do, so
                    // update our count to agree with them, and force-allow another requet
                    alreadySeen = callerSeen
                    _feedStoriesSeen.put(fs, callerSeen)
                    alreadyPending = 0
                }

                pendingFeed = fs
                pendingFeedTarget = desiredStoryCount

                if (fs != lastFeedSet) {
                    return true
                }
                if (desiredStoryCount <= alreadySeen) {
                    return false
                }
                if (desiredStoryCount <= alreadyPending) {
                    return false
                }
            }
            return true
        }

        override fun clearState() {
            pendingFeed = null
            resetFeed = null
            _followupActions.clear()
            _recountCandidates.clear()
            _exhaustedFeeds.clear()
            _feedPagesSeen.clear()
            _feedStoriesSeen.clear()

            UnreadsSubService.clear()
            ImagePrefetchSubService.clear()
        }

        override fun clearRecountCandidates() {
            _recountCandidates.clear()
        }

        override fun clearSeenFeedStories() {
            _feedStoriesSeen.clear()
        }

        override fun removeFeedStoriesSeen(fs: FeedSet) {
            _feedStoriesSeen.remove(fs)
        }

        override fun addFeedStoriesSeen(
            fs: FeedSet,
            count: Int,
        ) {
            _feedStoriesSeen[fs] = count
        }

        override fun clearSeenFeedPages() {
            _feedPagesSeen.clear()
        }

        override fun removeFeedPagesSeen(fs: FeedSet) {
            _feedPagesSeen.remove(fs)
        }

        override fun addFeedPagesSeen(
            fs: FeedSet,
            count: Int,
        ) {
            _feedPagesSeen[fs] = count
        }

        override fun clearExhaustedFeeds() {
            _exhaustedFeeds.clear()
        }

        override fun removeFeedSetExhausted(fs: FeedSet) {
            _exhaustedFeeds.remove(fs)
        }

        override fun addFeedSetExhausted(fs: FeedSet) {
            _exhaustedFeeds.add(fs)
        }

        override fun resetReadingSession(dbHelper: BlurDatabaseHelper) {
            Log.d(SyncServiceState::class.simpleName, "requesting reading session reset")
            synchronized(pendingFeedMutex) {
                pendingFeed = null
                dbHelper.sessionFeedSet = null
            }
        }

        override fun addRecountCandidates(impactedFeeds: Set<FeedSet>) {
            _recountCandidates.addAll(impactedFeeds)
        }

        override fun isFeedFolderSyncRunning(): Boolean =
            isHousekeepingRunning() ||
                serviceState.value is ServiceState.FolderFeedSync

        override fun isHousekeepingRunning(): Boolean = serviceState.value is ServiceState.Housekeeping

        override fun isFeedCountSyncRunning(): Boolean = isFeedFolderSyncRunning() || serviceState.value is ServiceState.RecountsSync
    }

interface ServiceState {
    data object Idle : ServiceState

    data object Housekeeping : ServiceState

    data object ActionsSync : ServiceState

    data object FolderFeedSync : ServiceState

    data object StorySync : ServiceState

    data object RecountsSync : ServiceState

    data object CleanupSync : ServiceState

    data object StarredSync : ServiceState

    data object UnreadsSync : ServiceState

    data object ImagePrefetchSync : ServiceState
}
