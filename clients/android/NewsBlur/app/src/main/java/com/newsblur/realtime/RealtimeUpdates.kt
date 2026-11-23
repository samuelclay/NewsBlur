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
import com.newsblur.util.StoryOrder
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
    /** What NewStoriesPill.kt's tap, or the row standing in for it, shows. */
    sealed interface TapResult {
        data object None : TapResult

        /** Add these to the list, pinned to its edge, with the arrival cascade. */
        data class Insert(
            val storyHashes: List<String>,
            val placement: NewStories.Placement,
        ) : TapResult

        /**
         * Past the cap on a newest-first list: show only these, the newest waiting, as if the list loaded right then,
         * and page the rest of the list from its first page again (ItemSetFragment.java).
         */
        data class Replace(
            val storyHashes: List<String>,
        ) : TapResult
    }

    data class NewStories(
        val feedSet: FeedSet?,
        val storyHashes: List<String>,
        val placement: Placement,
        // Waiting stories outside the NEW_STORIES_CAP a tap would show, counted without loading them.
        val unfetchedCount: Int = 0,
    ) {
        enum class Placement { TOP, BOTTOM }

        /** What the pill says: the fetched stories plus the announced ones it never fetched. */
        val count: Int get() = storyHashes.size + unfetchedCount

        /**
         * More stories wait than the pill holds: a tap shows the newest [NEW_STORIES_CAP] of them, replacing a
         * newest-first list (TapResult.Replace), instead of adding them all.
         */
        val overCap: Boolean get() = unfetchedCount > 0 || storyHashes.size > NEW_STORIES_CAP

        companion object {
            val NONE = NewStories(null, emptyList(), Placement.TOP)
        }
    }

    private val lock = Any()

    // RealtimeUpdates.kt: each sign-out bumps this, so a response requested for the previous account never writes.
    // It has its own lock, held across those writes, so only sign-out ever waits on one; the list and the pill take
    // [lock] from the main thread.
    private val accountLock = Any()
    private var accountGeneration = 0L

    // From stopForAccountChange until PrefsRepo.kt has wiped the previous account (accountChangeComplete), the
    // username and feeds still belong to it, so nothing subscribes.
    private var accountChanging = false
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
    // Announced stories that passed the open list's checks but aren't among the NEW_STORIES_CAP a tap would show, each
    // with its date in seconds. A refill (refillLocked) fetches some while they stay counted here until they land.
    private val unfetchedNewStories = LinkedHashMap<String, Long>()
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
     * PrefsRepo.kt calls this on logout and before a login-as, so no event reaches the next account. Nothing
     * subscribes again until [accountChangeComplete]: until then the username and feeds are still the old account's.
     */
    fun stopForAccountChange() {
        synchronized(accountLock) {
            accountGeneration++
            accountChanging = true
        }
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
        }
    }

    /**
     * PrefsRepo.kt wiped the previous account. The app stays in the foreground through a login, so listen for the
     * next account's first feed list.
     */
    fun accountChangeComplete() {
        synchronized(accountLock) { accountChanging = false }
        synchronized(lock) { if (foreground) startLocked() }
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
        val account = currentAccount()
        if (synchronized(accountLock) { accountChanging }) return
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
        // RealtimeUpdates.kt drops a subscription read under an account that has since signed out: connecting with
        // it would deliver the previous account's activity.
        synchronized(accountLock) {
            if (account != accountGeneration || accountChanging) return
            socketClient.connect(username, feeds)
        }
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

    private fun currentAccount(): Long = synchronized(accountLock) { accountGeneration }

    /**
     * Runs [write] only if the account that made the request is still signed in. It holds [accountLock], which
     * stopForAccountChange takes before PrefsRepo.kt wipes the database, so a late response can't restore the
     * previous account's stories or counts. [write] must not take [lock].
     */
    private inline fun writeForAccount(
        account: Long,
        write: () -> Unit,
    ): Boolean =
        synchronized(accountLock) {
            if (account != accountGeneration) return@synchronized false
            write()
            true
        }

    private suspend fun catchUpCounts() {
        repeat(CATCH_UP_ATTEMPTS) {
            if (!isLive()) return
            if (dbHelper.getUntriedActionCount() == 0) {
                val account = currentAccount()
                val response = feedApi.refreshFeedCounts()
                if (response == null || response.isError) {
                    Log.w(this, "catch-up count refresh failed")
                    return
                }
                if (!writeForAccount(account) { applyCounts(response) }) return
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
        // A story this device holds no copy of can't adjust its feed's count, and while the open list covers that
        // feed its feed:<id> update waits for the list to close; ask the server for those counts instead.
        val uncounted = dbHelper.storyHashesWithoutLocalCopy(batch.keys)
        if (uncounted.isNotEmpty()) {
            queueCounts(uncounted.map { it.substringBefore(':') }.filter { it.isNotBlank() }.distinct(), USER_UPDATE_DEBOUNCE_MILLIS)
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
                val account = currentAccount()
                val response = feedApi.getFeedUnreadCounts(apiIds.toMutableSet())
                if (response == null || response.isError) {
                    Log.w(this, "realtime count refresh failed for ${apiIds.size} feeds")
                } else {
                    writeForAccount(account) { applyCounts(response) }
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
     * NewStoriesPill.kt's tap. Up to the cap it adds the fetched stories. Past it, it picks the newest
     * [NEW_STORIES_CAP] waiting (the oldest, for an oldest-first list), which are already loaded, so it shows them
     * without a fetch; only one still on its way or whose fetch failed is fetched here. A newest-first list then shows
     * just those, and an oldest-first one adds them and keeps the rest waiting, loading the next 20 for its next tap.
     */
    suspend fun takeNewStoriesForTap(fs: FeedSet): TapResult {
        val account = currentAccount()
        val newestFirst: Boolean
        val picked: List<String>
        val toFetch: List<String>
        val alreadyFetched: Set<String>
        synchronized(lock) {
            val current = _newStories.value
            if (current.feedSet != fs || current.count == 0) return TapResult.None
            if (!current.overCap) {
                clearNewStoriesLocked()
                return TapResult.Insert(current.storyHashes, current.placement)
            }
            newestFirst = current.placement == NewStories.Placement.TOP
            val waiting = LinkedHashMap<String, Long>()
            current.storyHashes.forEach { waiting[it] = (newStoryTimestamps[it] ?: 0L) / 1000 }
            unfetchedNewStories.forEach { (hash, seconds) -> waiting.putIfAbsent(hash, seconds) }
            picked = NewStoryRules.pickForTap(waiting, NEW_STORIES_CAP, newestFirst)
            alreadyFetched = current.storyHashes.toSet()
            toFetch = picked.filter { it !in alreadyFetched }
            if (newestFirst) {
                // The list is about to show only the newest; everything else waiting goes with the list it was for.
                clearNewStoriesLocked()
            } else {
                val remaining = current.storyHashes.filter { it !in picked }
                picked.forEach { unfetchedNewStories.remove(it); newStoryTimestamps.remove(it) }
                _newStories.value =
                    if (remaining.isEmpty() && unfetchedNewStories.isEmpty()) {
                        NewStories.NONE
                    } else {
                        current.copy(storyHashes = remaining, unfetchedCount = unfetchedNewStories.size)
                    }
                if (_newStories.value.feedSet == fs) refillLocked(fs, newestFirst = false)
            }
        }
        val fetched = if (toFetch.isEmpty()) emptySet() else fetchShowable(fs, toFetch, account) ?: return TapResult.None
        val shown = picked.filter { it in alreadyFetched || it in fetched }
        if (shown.isEmpty()) return TapResult.None
        return if (newestFirst) TapResult.Replace(shown) else TapResult.Insert(shown, NewStories.Placement.BOTTOM)
    }

    /**
     * A tap past the cap on a newest-first list: the open list's reading session restarts with just [hashes], the
     * newest waiting, and its paging starts over from the first page. The session lists each story once, so later
     * pages skip these; the reader scrolls down to where they were.
     */
    fun showOnly(
        fs: FeedSet,
        hashes: List<String>,
        session: Long,
    ): Boolean {
        val account = currentAccount()
        var shown = false
        writeForAccount(account) {
            shown =
                inReadingSession(session) {
                    dbHelper.prepareOrderedReadingSession(fs, hashes)
                    syncServiceState.restartPaging(fs)
                }
        }
        return shown
    }

    /** A tap up to the cap: adds [hashes] to the open list, unless it was switched or reloaded since [session]. */
    fun addToOpenList(
        hashes: List<String>,
        session: Long,
    ): Boolean = inReadingSession(session) { dbHelper.addStoriesToReadingSession(hashes) }

    /**
     * The open list's reading session when NewStoriesPill.kt was tapped. A tap's fetch can outlast the list: on a
     * tablet the same story list switches feeds, and a reload restarts the same feed's session.
     */
    fun readingSession(): Long = dbHelper.getReadingSessionVersion()

    // Paging the same session leaves the version alone, so a page loading during the tap's fetch never drops its
    // stories. The paging lock keeps a page from landing mid-write, and the database lock, which every session change
    // takes, keeps a switch or reload out. Same order as SyncService.kt's page commits: paging lock, then database.
    private inline fun inReadingSession(
        session: Long,
        write: () -> Unit,
    ): Boolean =
        synchronized(syncServiceState.pendingFeedMutex) {
            synchronized(BlurDatabaseHelper.RW_MUTEX) {
                if (dbHelper.getReadingSessionVersion() != session) return false
                write()
                true
            }
        }

    /**
     * Fetches [hashes] in one request and stores them, returning those the open list shows: its feeds, its read and
     * Focus filters, and never a story the reader's classifiers hide. Null when the request failed or the account
     * changed meanwhile.
     */
    private suspend fun fetchShowable(
        fs: FeedSet,
        hashes: List<String>,
        account: Long,
    ): Set<String>? {
        val response = storyApi.getStoriesByHash(hashes)
        val stories = response?.stories
        if (response == null || response.isError || stories == null) {
            Log.w(this, "couldn't fetch ${hashes.size} new stories")
            return null
        }
        val filters = CursorFilters(prefsRepo, fs)
        if (!writeForAccount(account) { dbHelper.insertStories(response, filters.stateFilter, false) }) return null
        val subscribed = synchronized(lock) { subscribedFeedIds }
        return stories.filter { it.storyHash in hashes && showsInList(it, fs, filters, subscribed) }.map { it.storyHash }.toSet()
    }

    private fun showsInList(
        story: com.newsblur.domain.Story,
        fs: FeedSet,
        filters: CursorFilters,
        subscribed: Set<String>,
    ): Boolean =
        NewStoryRules.listAccepts(fs, story.feedId, subscribed) &&
            // The pill never offers a story the reader's classifiers hide, even in the All state; a reload or a page
            // still lists it there.
            story.intelligence.calcTotalIntel() >= 0 &&
            story.isStoryVisibleInState(filters.stateFilter) &&
            (filters.readFilter == ReadFilter.ALL || !story.read)

    private fun clearNewStoriesLocked() {
        newStoryFetchJob?.cancel()
        newStoryFetchJob = null
        pendingNewStories.clear()
        unfetchedNewStories.clear()
        newStoryTimestamps.clear()
        _newStories.value = NewStories.NONE
    }

    /** The loaded stories waiting for the open list, each with its date in seconds. */
    private fun loadedSecondsLocked(fs: FeedSet): Map<String, Long> =
        _newStories.value.takeIf { it.feedSet == fs }?.storyHashes?.associateWith { (newStoryTimestamps[it] ?: 0L) / 1000 } ?: emptyMap()

    /**
     * A loaded story read elsewhere, or one that turned out not to show, leaves a slot among the 20 a tap would show;
     * the newest counted stories fill it (the oldest, for an oldest-first list), so the tap still has them all loaded.
     * They stay counted until they land.
     */
    private fun refillLocked(
        fs: FeedSet,
        newestFirst: Boolean,
    ) {
        val room = NEW_STORIES_CAP - loadedSecondsLocked(fs).size - pendingNewStories.size
        if (room <= 0) return
        val counted = unfetchedNewStories.filterKeys { it !in pendingNewStories }
        if (counted.isEmpty()) return
        NewStoryRules.pickForTap(counted, room, newestFirst).forEach { pendingNewStories[it] = counted.getValue(it) }
        if (newStoryFetchJob?.isActive == true) return
        newStoryFetchJob =
            scope.launch {
                delay(NEW_STORY_THROTTLE_MILLIS)
                fetchNewStories(fs)
            }
    }

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
            ) {
                return
            }
            // RealtimeUpdates.kt keeps the 20 stories a tap would show loaded. A story that isn't among them, by date in
            // the list's order, is only counted, so a list left open overnight never holds more than 20.
            val held = loadedSecondsLocked(fs).values + pendingNewStories.values
            if (!NewStoryRules.belongsAmongLoaded(message.timestampSeconds, held, NEW_STORIES_CAP, order == StoryOrder.NEWEST)) {
                unfetchedNewStories[message.storyHash] = message.timestampSeconds
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
        // Taken before [lock], never inside it: a write holding accountLock must not keep the main thread waiting.
        val account = currentAccount()
        val requested =
            synchronized(lock) {
                newStoryFetchJob = null
                if (openList != fs) return
                if (!prefsRepo.isNewStoriesPillEnabled()) {
                    clearNewStoriesLocked()
                    return
                }
                // Load only those among the 20 a tap would show, with what's loaded already; newer arrivals since may
                // have pushed some waiting stories out of them, and those are counted instead.
                val newestFirst = CursorFilters(prefsRepo, fs).storyOrder == StoryOrder.NEWEST
                val kept = NewStoryRules.pickForTap(loadedSecondsLocked(fs) + pendingNewStories, NEW_STORIES_CAP, newestFirst).toSet()
                val outside = pendingNewStories.filterKeys { it !in kept }
                if (outside.isNotEmpty()) {
                    outside.forEach { (hash, seconds) ->
                        unfetchedNewStories.putIfAbsent(hash, seconds)
                        pendingNewStories.remove(hash)
                    }
                    publishUnfetchedLocked(fs)
                }
                pendingNewStories.entries.take(MAX_HASHES_PER_FETCH).associate { it.key to it.value }.also {
                    it.keys.forEach(pendingNewStories::remove)
                }
            }
        if (requested.isEmpty()) return
        val hashes = requested.keys.toList()
        if (BuildConfig.DEBUG) android.util.Log.d(LOG_TAG, "fetching new stories $hashes")
        val response = storyApi.getStoriesByHash(hashes)
        val stories = response?.stories
        if (response == null || response.isError || stories == null) {
            Log.w(this, "couldn't fetch ${hashes.size} new stories")
            // They keep waiting, counted, so a tap can fetch the ones it shows.
            synchronized(lock) {
                if (openList != fs) return
                requested.forEach { (hash, seconds) -> unfetchedNewStories.putIfAbsent(hash, seconds) }
                publishUnfetchedLocked(fs)
            }
            return
        }
        val filters = CursorFilters(prefsRepo, fs)
        // BlurDatabaseHelper.java stores them for the tap without adding them to the open list yet,
        // and settles each one's read state against what this device already knows.
        if (!writeForAccount(account) { dbHelper.insertStories(response, filters.stateFilter, false) }) return
        val placement = NewStoryRules.placement(filters.storyOrder, syncServiceState.isFeedSetExhausted(fs)) ?: return
        val subscribed = synchronized(lock) { subscribedFeedIds }
        val accepted =
            stories.filter { story ->
                story.storyHash in hashes && showsInList(story, fs, filters, subscribed) &&
                    !dbHelper.isStoryInReadingSession(story.storyHash)
            }
        if (BuildConfig.DEBUG) {
            android.util.Log.d(LOG_TAG, "fetched ${stories.size} new stories, ${accepted.size} shown by the list's filter")
        }
        synchronized(lock) {
            if (openList != fs) return
            // Each one fetched leaves the count: it's loaded now, or it never counted (hidden, read, or not in the list).
            hashes.forEach(unfetchedNewStories::remove)
            accepted.forEach { newStoryTimestamps[it.storyHash] = it.timestamp }
            val shown = _newStories.value
            val current = if (shown.feedSet == fs) shown.storyHashes else emptyList()
            val merged = (current + accepted.map { it.storyHash }).distinct()
            val newestFirst = placement == NewStories.Placement.TOP
            // RealtimeUpdates.kt keeps the 20 a tap would show, in the list's order; a newer arrival pushes the oldest
            // of them back to the count, its date kept.
            val dates = merged.associateWith { (newStoryTimestamps[it] ?: 0L) / 1000 }
            val ordered = NewStoryRules.pickForTap(dates, NEW_STORIES_CAP, newestFirst)
            (merged - ordered.toSet()).forEach {
                unfetchedNewStories[it] = dates.getValue(it)
                newStoryTimestamps.remove(it)
            }
            if (ordered.isNotEmpty() || unfetchedNewStories.isNotEmpty()) {
                _newStories.value = NewStories(fs, ordered, placement, unfetchedNewStories.size)
            } else if (shown.feedSet == fs) {
                _newStories.value = NewStories.NONE
            }
            refillLocked(fs, newestFirst)
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
            unfetchedNewStories.keys.removeAll(read)
            if (remaining.size == current.storyHashes.size && unfetchedNewStories.size == unfetchedBefore) return
            _newStories.value =
                if (remaining.isEmpty() && unfetchedNewStories.isEmpty()) {
                    NewStories.NONE
                } else {
                    current.copy(storyHashes = remaining, unfetchedCount = unfetchedNewStories.size)
                }
            if (_newStories.value.feedSet == fs) refillLocked(fs, current.placement == NewStories.Placement.TOP)
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
        val account = currentAccount()
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
        if (!writeForAccount(account) { dbHelper.replaceStarredCounts(values) }) return
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

        // How many waiting stories the pill keeps loaded: the newest (oldest, for an oldest-first list), the ones a tap
        // past the cap shows. The rest are only counted.
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
