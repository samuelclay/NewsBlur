package com.newsblur.realtime

import android.content.ContentValues
import android.content.Context
import com.newsblur.BuildConfig
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.StarredCount
import com.newsblur.network.APIConstants
import com.newsblur.network.FeedApi
import com.newsblur.network.NewsBlurSocketClient
import com.newsblur.network.StoryApi
import com.newsblur.network.domain.UnreadCountResponse
import com.newsblur.preference.PrefsRepo
import com.newsblur.service.NBSync
import com.newsblur.service.NbSyncManager
import com.newsblur.service.NbSyncManager.UPDATE_METADATA
import com.newsblur.service.NbSyncManager.UPDATE_STORY
import com.newsblur.service.SyncServiceState
import com.newsblur.util.CursorFilters
import com.newsblur.util.FeedSet
import com.newsblur.util.FeedUtils
import com.newsblur.util.Log
import com.newsblur.util.ReadFilter
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.random.Random

/**
 * Live updates over the Socket.IO connection to node/unread_counts.coffee, matching the web's
 * setup_socket_realtime_unread_counts in media/js/newsblur/reader/reader.js: reads and unreads made
 * on other devices, unread counts, saved counts, feed list reloads, and stories for the open list's
 * "new stories" pill (NewStoriesPill.kt). NbApplication.kt connects it while the app is in the
 * foreground; a connection that starts after a gap refreshes every count once to catch what it missed.
 */
@Singleton
class RealtimeUpdates internal constructor(
    private val socketClient: NewsBlurSocketClient,
    private val prefsRepo: PrefsRepo,
    private val dbHelper: BlurDatabaseHelper,
    private val feedApi: FeedApi,
    private val storyApi: StoryApi,
    private val syncServiceState: SyncServiceState,
    private val scope: CoroutineScope,
    private val clock: () -> Long,
    private val random: Random,
    private val requestSync: () -> Unit,
    private val submitUpdate: (Int) -> Unit,
) {
    @Inject
    constructor(
        @ApplicationContext context: Context,
        socketClient: NewsBlurSocketClient,
        prefsRepo: PrefsRepo,
        dbHelper: BlurDatabaseHelper,
        feedApi: FeedApi,
        storyApi: StoryApi,
        syncServiceState: SyncServiceState,
    ) : this(
        socketClient = socketClient,
        prefsRepo = prefsRepo,
        dbHelper = dbHelper,
        feedApi = feedApi,
        storyApi = storyApi,
        syncServiceState = syncServiceState,
        scope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
        clock = System::currentTimeMillis,
        random = Random.Default,
        requestSync = { FeedUtils.triggerSync(context) },
        submitUpdate = NbSyncManager::submitUpdate,
    )

    /** Stories RealtimeUpdates.kt fetched for the open list, waiting for a tap on NewStoriesPill.kt. */
    data class NewStories(
        val feedSet: FeedSet?,
        val storyHashes: List<String>,
        val placement: Placement,
        // Announced stories past the cap, counted without fetching them.
        val unfetchedCount: Int = 0,
    ) {
        enum class Placement { TOP, BOTTOM }

        /** What the pill says: the fetched stories plus the announced ones it never fetched. */
        val count: Int get() = storyHashes.size + unfetchedCount

        /**
         * More stories than the pill holds: a tap reloads the list's newest page and fills the gap below it
         * (ItemSetFragment.java) instead of adding these.
         */
        val fillsGap: Boolean get() = unfetchedCount > 0 || storyHashes.size > NEW_STORIES_CAP

        companion object {
            val NONE = NewStories(null, emptyList(), Placement.TOP)
        }
    }

    private val lock = Any()
    private var foreground = false
    private var subscribedFeedIds: Set<String> = emptySet()
    private var lastSubscription: List<String> = emptyList()
    private var liveSince: Long? = null
    private var countsCurrentWhileLive = false
    private var lifecycleJobs: List<Job> = emptyList()

    private val countBatcher = UnreadCountBatcher()
    private var flushJob: Job? = null
    private var flushAt = Long.MAX_VALUE

    private var openList: FeedSet? = null
    private val deferredForOpenList = mutableSetOf<String>()

    private val pendingReads = LinkedHashMap<String, Boolean>()
    private var readFlushJob: Job? = null
    private var starredJob: Job? = null
    private var reloadJob: Job? = null

    private val pendingNewStories = LinkedHashMap<String, Long>()
    // Announced stories that passed the open list's checks after the pill reached its cap.
    private val unfetchedNewStories = LinkedHashSet<String>()
    private val newStoryTimestamps = HashMap<String, Long>()
    private var newStoryFetchJob: Job? = null
    private val _newStories = MutableStateFlow(NewStories.NONE)
    val newStories: StateFlow<NewStories> = _newStories.asStateFlow()

    init {
        for (event in RealtimeMessage.EVENTS) {
            socketClient.subscribeArguments(event) { arguments -> onSocketEvent(event, arguments) }
        }
    }

    // ===== Lifecycle =====

    fun onAppForeground() {
        synchronized(lock) {
            if (foreground) return
            foreground = true
            startLocked()
        }
    }

    @OptIn(FlowPreview::class)
    private fun startLocked() {
        lifecycleJobs.forEach(Job::cancel)
        lifecycleJobs =
            listOf(
                scope.launch { socketClient.subscribed.collect(::onLiveChanged) },
                // SyncService.kt rewrites the feed list during a metadata sync, including the first one
                // after a login; connect or resubscribe once it settles.
                scope.launch {
                    NbSyncManager.state
                        .filter { it is NBSync.Update && (it.type and UPDATE_METADATA) != 0 }
                        .debounce(SUBSCRIPTION_DEBOUNCE_MILLIS)
                        .collect { refreshSubscription() }
                },
                scope.launch { refreshSubscription() },
            )
    }

    fun onAppBackground() {
        synchronized(lock) {
            if (!foreground) return
            foreground = false
        }
        stopConnection()
    }

    /**
     * PrefsRepo.kt calls this on logout and before a login-as, so no event reaches the next account.
     * The app stays in the foreground through a login, so listen for the next account's first feed list.
     */
    fun stopForAccountChange() {
        stopConnection()
        synchronized(lock) {
            subscribedFeedIds = emptySet()
            openList = null
            deferredForOpenList.clear()
            pendingReads.clear()
            readFlushJob?.cancel()
            starredJob?.cancel()
            reloadJob?.cancel()
            clearNewStoriesLocked()
            if (foreground) startLocked()
        }
    }

    private fun stopConnection() {
        synchronized(lock) {
            lifecycleJobs.forEach(Job::cancel)
            lifecycleJobs = emptyList()
            flushJob?.cancel()
            flushJob = null
            flushAt = Long.MAX_VALUE
            newStoryFetchJob?.cancel()
            newStoryFetchJob = null
            pendingNewStories.clear()
        }
        // The catch-up after the next connection covers every count this batch would have refreshed.
        countBatcher.clear()
        synchronized(lock) { lastSubscription = emptyList() }
        socketClient.disconnect()
        onLiveChanged(false)
    }

    internal suspend fun refreshSubscription() {
        val username = prefsRepo.getUserName() ?: return
        if (!prefsRepo.hasCookie()) return
        val active = dbHelper.getAllActiveFeeds()
        val feeds = active.sorted() + dbHelper.getAllSocialFeeds().sorted().map { APIConstants.VALUE_PREFIX_SOCIAL + it }
        if (feeds.isEmpty()) return
        synchronized(lock) {
            subscribedFeedIds = active
            if (!foreground) return
            if (feeds != lastSubscription) Log.i(this, "realtime subscribing to ${feeds.size} feeds")
            lastSubscription = feeds
        }
        socketClient.connect(username, feeds)
    }

    internal fun onLiveChanged(live: Boolean) {
        synchronized(lock) {
            if (!live) {
                if (liveSince != null) Log.i(this, "realtime disconnected")
                liveSince = null
                countsCurrentWhileLive = false
                return
            }
            if (liveSince != null) return
            liveSince = clock()
            Log.i(this, "realtime live")
            // SyncService.kt just loaded the feed list with counts, so there is nothing to catch up on.
            if (clock() - prefsRepo.getLastSyncTime() < FRESH_SYNC_MILLIS) {
                countsCurrentWhileLive = true
                return
            }
        }
        scope.launch { catchUpCounts() }
    }

    /**
     * SyncService.kt skips its periodic feed list reload while the socket has kept counts current since
     * the last one, up to [MAX_SKIPPED_SYNC_MILLIS] in case the server side quietly stopped publishing.
     */
    fun keepsCountsCurrent(lastSyncTime: Long): Boolean =
        synchronized(lock) {
            liveSince != null && countsCurrentWhileLive && clock() - lastSyncTime < MAX_SKIPPED_SYNC_MILLIS
        }

    private fun isLive(): Boolean = synchronized(lock) { liveSince != null }

    private suspend fun catchUpCounts() {
        repeat(CATCH_UP_ATTEMPTS) {
            if (!isLive()) return
            if (dbHelper.getUntriedActionCount() == 0) {
                val response = feedApi.refreshFeedCounts()
                if (response == null || response.isError) {
                    Log.w(this, "catch-up count refresh failed")
                    return
                }
                applyCounts(response)
                synchronized(lock) { if (liveSince != null) countsCurrentWhileLive = true }
                return
            }
            delay(PENDING_ACTION_RETRY_MILLIS)
        }
        // Reads queued on this device haven't reached the server yet. SyncService.kt sends them first,
        // then reloads the feed list with counts.
        syncServiceState.forceFeedsFolders()
        requestSync()
    }

    // ===== Events =====

    private fun onSocketEvent(
        event: String,
        arguments: List<Any?>,
    ) {
        val message = RealtimeMessage.parse(event, arguments)
        if (BuildConfig.DEBUG) android.util.Log.d(LOG_TAG, "$event: ${message ?: "ignored $arguments"}")
        if (message == null) return
        scope.launch { handle(message) }
    }

    internal fun handle(message: RealtimeMessage) {
        when (message) {
            is RealtimeMessage.StoryReadState -> queueRead(message.storyHash, message.read)
            is RealtimeMessage.CountsChanged -> queueCountsForMessage(message.feedIds, message.skipOpenList)
            is RealtimeMessage.StarredChanged -> onStarredChanged(message)
            RealtimeMessage.InteractionNew -> Unit // No Android screen shows an unread interactions badge.
            RealtimeMessage.ReloadFeeds -> scheduleFeedListReload()
            is RealtimeMessage.FeedFetched ->
                queueCounts(listOf(message.feedId), subscriberJitter(message.feedId, FETCH_JITTER_PER_SUBSCRIBER, FETCH_JITTER_CAP))
            is RealtimeMessage.NewStory -> onNewStory(message)
        }
    }

    // ===== Read state =====

    private fun queueRead(
        storyHash: String,
        read: Boolean,
    ) {
        synchronized(lock) {
            pendingReads[storyHash] = read
            if (readFlushJob?.isActive == true) return
            // Marking a folder read on the web sends one story:read per story; apply them together.
            readFlushJob =
                scope.launch {
                    delay(READ_BATCH_MILLIS)
                    flushReads()
                }
        }
    }

    private fun flushReads() {
        val batch =
            synchronized(lock) {
                readFlushJob = null
                LinkedHashMap(pendingReads).also { pendingReads.clear() }
            }
        val readHashes = mutableListOf<String>()
        var applied = false
        for (read in listOf(true, false)) {
            // Our own reads come back from the server too; they already match and change nothing.
            val hashes = batch.filterValues { it == read }.keys.filter { dbHelper.isStoryRead(it) != read }
            if (hashes.isEmpty()) continue
            dbHelper.applyRemoteStoryReadHashes(hashes, read)
            applied = true
            if (read) readHashes += hashes
        }
        if (!applied) return
        dropReadFromNewStories(readHashes)
        submitUpdate(UPDATE_STORY or UPDATE_METADATA)
    }

    // ===== Counts =====

    private fun queueCountsForMessage(
        apiIds: List<String>,
        skipOpenList: Boolean,
    ) {
        val refreshNow =
            synchronized(lock) {
                val open = openList
                if (!skipOpenList || open == null) {
                    apiIds
                } else {
                    // The open list's counts follow story:read; a server count could race our own queued reads.
                    val (deferred, now) = apiIds.partition { open.coversApiId(it) }
                    deferredForOpenList += deferred
                    now
                }
            }
        queueCounts(refreshNow, USER_UPDATE_DEBOUNCE_MILLIS)
    }

    private fun queueCounts(
        apiIds: Collection<String>,
        delayMillis: Long,
    ) {
        if (apiIds.isEmpty()) return
        countBatcher.add(apiIds, clock() + delayMillis)
        scheduleFlush()
    }

    private fun scheduleFlush() {
        val next = countBatcher.nextDueAt() ?: return
        synchronized(lock) {
            if (flushJob?.isActive == true && flushAt <= next) return
            flushJob?.cancel()
            flushAt = next
            flushJob =
                scope.launch {
                    delay((next - clock()).coerceAtLeast(0))
                    flushCounts()
                }
        }
    }

    private suspend fun flushCounts() {
        synchronized(lock) {
            flushJob = null
            flushAt = Long.MAX_VALUE
        }
        val apiIds = countBatcher.takeDue(clock())
        if (apiIds.isNotEmpty() && isLive()) {
            if (dbHelper.getUntriedActionCount() > 0) {
                // Like SyncService.kt checkRecounts: a count taken before queued reads land would undo them.
                countBatcher.add(apiIds, clock() + PENDING_ACTION_RETRY_MILLIS)
            } else {
                if (BuildConfig.DEBUG) android.util.Log.d(LOG_TAG, "refreshing counts for $apiIds")
                val response = feedApi.getFeedUnreadCounts(apiIds.toMutableSet())
                if (response == null || response.isError) {
                    Log.w(this, "realtime count refresh failed for ${apiIds.size} feeds")
                } else {
                    applyCounts(response)
                }
            }
        }
        scheduleFlush()
    }

    private fun applyCounts(response: UnreadCountResponse) {
        response.feeds?.forEach { (feedId, counts) -> dbHelper.updateFeedCounts(feedId, counts.values) }
        response.socialFeeds?.forEach { (feedId, counts) ->
            dbHelper.updateSocialFeedCounts(feedId.removePrefix(APIConstants.VALUE_PREFIX_SOCIAL), counts.valuesSocial)
        }
        submitUpdate(UPDATE_METADATA)
    }

    private fun subscriberJitter(
        feedId: String,
        perSubscriberMillis: Long,
        capMillis: Long,
    ): Long {
        // reader.js spreads a popular feed's refreshes out: 6,000 subscribers wait up to a minute.
        val subscribers = dbHelper.getFeed(feedId)?.subscribers?.toLongOrNull() ?: 0L
        val maxDelay = (subscribers * perSubscriberMillis).coerceAtMost(capMillis)
        return if (maxDelay <= 0L) 0L else random.nextLong(maxDelay + 1)
    }

    // ===== Open story list =====

    /** ItemSetFragment.java reports the story list on screen, which RealtimeUpdates.kt keeps counts and the pill for. */
    fun setOpenStoryList(fs: FeedSet) {
        val released =
            synchronized(lock) {
                if (openList == fs) return
                openList = fs
                clearNewStoriesLocked()
                deferredForOpenList.toList().also { deferredForOpenList.clear() }
            }
        queueCounts(released, USER_UPDATE_DEBOUNCE_MILLIS)
    }

    fun clearOpenStoryList(fs: FeedSet) {
        val released =
            synchronized(lock) {
                if (openList != fs) return
                openList = null
                clearNewStoriesLocked()
                deferredForOpenList.toList().also { deferredForOpenList.clear() }
            }
        // Counts deferred while the list was open are refreshed now that our own reads have settled.
        queueCounts(released, USER_UPDATE_DEBOUNCE_MILLIS)
    }

    /** SettingsFragment.kt changed "Show new stories as they arrive"; turned off, the pill and what it held go away. */
    fun newStoriesSettingChanged() {
        if (prefsRepo.isNewStoriesPillEnabled()) return
        synchronized(lock) { clearNewStoriesLocked() }
    }

    /** ItemsList.java restarted the list with new filters, so buffered stories may no longer belong. */
    fun resetNewStories(fs: FeedSet) {
        synchronized(lock) {
            if (openList == fs) clearNewStoriesLocked()
        }
    }

    /**
     * NewStoriesPill.kt takes what the pill offered: the buffered stories to add to the open list, or, past
     * the cap, the signal to reload its newest page (NewStories.fillsGap). Either way the pill starts over.
     */
    fun takeNewStories(fs: FeedSet): NewStories =
        synchronized(lock) {
            val current = _newStories.value
            if (current.feedSet != fs) return NewStories.NONE
            clearNewStoriesLocked()
            current
        }

    private fun clearNewStoriesLocked() {
        newStoryFetchJob?.cancel()
        newStoryFetchJob = null
        pendingNewStories.clear()
        unfetchedNewStories.clear()
        newStoryTimestamps.clear()
        _newStories.value = NewStories.NONE
    }

    private fun bufferedNewStoryCountLocked(fs: FeedSet): Int =
        _newStories.value.takeIf { it.feedSet == fs }?.storyHashes?.size ?: 0

    private fun publishUnfetchedLocked(fs: FeedSet) {
        val current = _newStories.value
        val placement = NewStoryRules.placement(CursorFilters(prefsRepo, fs).storyOrder, true) ?: current.placement
        val base = if (current.feedSet == fs) current else NewStories(fs, emptyList(), placement)
        _newStories.value = base.copy(unfetchedCount = unfetchedNewStories.size)
    }

    private fun FeedSet.coversApiId(apiId: String): Boolean {
        if (apiId.startsWith(APIConstants.VALUE_PREFIX_SOCIAL)) {
            val userId = apiId.removePrefix(APIConstants.VALUE_PREFIX_SOCIAL)
            return isAllSocial || singleSocialFeed?.key == userId || multipleSocialFeeds?.containsKey(userId) == true
        }
        return isAllNormal || isInfrequent || singleFeed == apiId || multipleFeeds?.contains(apiId) == true
    }

    // ===== New stories pill =====

    private fun onNewStory(message: RealtimeMessage.NewStory) {
        // With "Show new stories as they arrive" off, the list gains stories only when it reloads or syncs.
        if (!prefsRepo.isNewStoriesPillEnabled()) return
        val fs = synchronized(lock) { openList } ?: return
        if (message.timestampSeconds > clock() / 1000 + FUTURE_STORY_SECONDS) return
        if (!NewStoryRules.listAccepts(fs, message.feedId, synchronized(lock) { subscribedFeedIds })) return
        val order = CursorFilters(prefsRepo, fs).storyOrder
        NewStoryRules.placement(order, syncServiceState.isFeedSetExhausted(fs)) ?: return
        if (dbHelper.isStoryInReadingSession(message.storyHash)) return
        val wait = maxOf(NEW_STORY_THROTTLE_MILLIS, subscriberJitter(message.feedId, NEW_STORY_JITTER_PER_SUBSCRIBER, NEW_STORY_JITTER_CAP))
        synchronized(lock) {
            if (openList != fs) return
            if (message.storyHash in pendingNewStories || message.storyHash in _newStories.value.storyHashes ||
                message.storyHash in unfetchedNewStories
            ) return
            if (bufferedNewStoryCountLocked(fs) >= NEW_STORIES_CAP) {
                // A list left open overnight would otherwise fetch every story published since.
                unfetchedNewStories += message.storyHash
                publishUnfetchedLocked(fs)
                return
            }
            pendingNewStories[message.storyHash] = message.timestampSeconds
            if (newStoryFetchJob?.isActive == true) return
            newStoryFetchJob =
                scope.launch {
                    delay(wait)
                    fetchNewStories(fs)
                }
        }
    }

    private suspend fun fetchNewStories(fs: FeedSet) {
        val hashes =
            synchronized(lock) {
                newStoryFetchJob = null
                if (openList != fs) return
                if (!prefsRepo.isNewStoriesPillEnabled()) {
                    clearNewStoriesLocked()
                    return
                }
                // Fetch only as many as the pill can still hold; the rest are counted, not fetched.
                val room = NEW_STORIES_CAP - bufferedNewStoryCountLocked(fs)
                if (room <= 0) {
                    unfetchedNewStories += pendingNewStories.keys
                    pendingNewStories.clear()
                    publishUnfetchedLocked(fs)
                    return
                }
                pendingNewStories.keys.take(minOf(room, MAX_HASHES_PER_FETCH)).onEach(pendingNewStories::remove)
            }
        if (hashes.isEmpty()) return
        if (BuildConfig.DEBUG) android.util.Log.d(LOG_TAG, "fetching new stories $hashes")
        val response = storyApi.getStoriesByHash(hashes)
        val stories = response?.stories
        if (response == null || response.isError || stories == null) {
            Log.w(this, "couldn't fetch ${hashes.size} new stories")
            return
        }
        val filters = CursorFilters(prefsRepo, fs)
        // BlurDatabaseHelper.java stores them for the tap without adding them to the open list yet,
        // and settles each one's read state against what this device already knows.
        dbHelper.insertStories(response, filters.stateFilter, false)
        val placement = NewStoryRules.placement(filters.storyOrder, syncServiceState.isFeedSetExhausted(fs)) ?: return
        val subscribed = synchronized(lock) { subscribedFeedIds }
        val accepted =
            stories.filter { story ->
                story.storyHash in hashes &&
                    NewStoryRules.listAccepts(fs, story.feedId, subscribed) &&
                    story.isStoryVisibleInState(filters.stateFilter) &&
                    (filters.readFilter == ReadFilter.ALL || !story.read) &&
                    !dbHelper.isStoryInReadingSession(story.storyHash)
            }
        if (BuildConfig.DEBUG) {
            android.util.Log.d(LOG_TAG, "fetched ${stories.size} new stories, ${accepted.size} shown by the list's filter")
        }
        synchronized(lock) {
            if (openList != fs) return
            accepted.forEach { newStoryTimestamps[it.storyHash] = it.timestamp }
            val shown = _newStories.value
            val current = if (shown.feedSet == fs) shown.storyHashes else emptyList()
            val merged = (current + accepted.map { it.storyHash }).distinct()
            val ordered =
                if (placement == NewStories.Placement.TOP) {
                    merged.sortedByDescending { newStoryTimestamps[it] ?: 0L }
                } else {
                    merged.sortedBy { newStoryTimestamps[it] ?: 0L }
                }
            if (ordered.isNotEmpty() || unfetchedNewStories.isNotEmpty()) {
                _newStories.value = NewStories(fs, ordered, placement, unfetchedNewStories.size)
            }
            if (pendingNewStories.isNotEmpty() && newStoryFetchJob?.isActive != true) {
                newStoryFetchJob =
                    scope.launch {
                        delay(NEW_STORY_THROTTLE_MILLIS)
                        fetchNewStories(fs)
                    }
            }
        }
    }

    private fun dropReadFromNewStories(readHashes: List<String>) {
        if (readHashes.isEmpty()) return
        synchronized(lock) {
            val current = _newStories.value
            val fs = current.feedSet ?: return
            // A story read elsewhere no longer belongs in an unread-only list's pill.
            if (CursorFilters(prefsRepo, fs).readFilter != ReadFilter.UNREAD) return
            val read = readHashes.toSet()
            val remaining = current.storyHashes - read
            pendingNewStories.keys.removeAll(read)
            val unfetchedBefore = unfetchedNewStories.size
            unfetchedNewStories.removeAll(read)
            if (remaining.size == current.storyHashes.size && unfetchedNewStories.size == unfetchedBefore) return
            _newStories.value =
                if (remaining.isEmpty() && unfetchedNewStories.isEmpty()) {
                    NewStories.NONE
                } else {
                    current.copy(storyHashes = remaining, unfetchedCount = unfetchedNewStories.size)
                }
        }
    }

    // ===== Saved stories and feed list =====

    private fun onStarredChanged(message: RealtimeMessage.StarredChanged) {
        message.storyHash?.let { dbHelper.markStoryHashesStarred(listOf(it), message.starred) }
        synchronized(lock) {
            starredJob?.cancel()
            starredJob =
                scope.launch {
                    delay(STARRED_DEBOUNCE_MILLIS)
                    refreshStarredCounts()
                }
        }
    }

    private suspend fun refreshStarredCounts() {
        val response = feedApi.getStarredCounts()
        if (response == null || response.isError) {
            Log.w(this, "saved story count refresh failed")
            return
        }
        // SyncService.kt stores the total as a pseudo-tag row; keep that shape.
        val values: MutableList<ContentValues> = response.starredCounts.map(StarredCount::getValues).toMutableList()
        values +=
            StarredCount()
                .apply {
                    count = response.starredCount
                    tag = StarredCount.TOTAL_STARRED
                }.values
        dbHelper.replaceStarredCounts(values)
        submitUpdate(UPDATE_METADATA or UPDATE_STORY)
    }

    private fun scheduleFeedListReload() {
        synchronized(lock) {
            reloadJob?.cancel()
            // An OPML import or a folder move sends several reloads in a row; load the feed list once.
            reloadJob =
                scope.launch {
                    delay(RELOAD_DEBOUNCE_MILLIS)
                    syncServiceState.forceFeedsFolders()
                    requestSync()
                }
        }
    }

    @EntryPoint
    @InstallIn(SingletonComponent::class)
    interface RealtimeUpdatesEntryPoint {
        fun realtimeUpdates(): RealtimeUpdates
    }

    companion object {
        private const val LOG_TAG = "NBRealtime"
        internal const val USER_UPDATE_DEBOUNCE_MILLIS = 1_000L
        internal const val READ_BATCH_MILLIS = 250L
        internal const val FETCH_JITTER_PER_SUBSCRIBER = 10L
        internal const val FETCH_JITTER_CAP = 60_000L
        internal const val NEW_STORY_THROTTLE_MILLIS = 1_000L
        internal const val NEW_STORY_JITTER_PER_SUBSCRIBER = 2L
        internal const val NEW_STORY_JITTER_CAP = 10_000L
        internal const val PENDING_ACTION_RETRY_MILLIS = 2_000L
        internal const val CATCH_UP_ATTEMPTS = 10
        internal const val FRESH_SYNC_MILLIS = 60_000L
        internal const val MAX_SKIPPED_SYNC_MILLIS = 60L * 60L * 1000L
        internal const val FUTURE_STORY_SECONDS = 60L * 60L
        internal const val MAX_HASHES_PER_FETCH = 100

        // The most stories the pill fetches and holds; past it, announcements are only counted.
        const val NEW_STORIES_CAP = 20
        private const val STARRED_DEBOUNCE_MILLIS = 1_000L
        private const val RELOAD_DEBOUNCE_MILLIS = 2_000L
        private const val SUBSCRIPTION_DEBOUNCE_MILLIS = 1_000L

        @JvmStatic
        fun from(context: Context): RealtimeUpdates =
            EntryPointAccessors
                .fromApplication(context.applicationContext, RealtimeUpdatesEntryPoint::class.java)
                .realtimeUpdates()
    }
}
