package com.newsblur.service

import android.app.job.JobParameters
import android.app.job.JobService
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.Cursor
import com.newsblur.NbApplication
import com.newsblur.NbApplication.Companion.isAppForeground
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.database.DatabaseConstants
import com.newsblur.di.IconFileCache
import com.newsblur.di.StoryImageCache
import com.newsblur.di.ThumbnailCache
import com.newsblur.domain.Feed
import com.newsblur.domain.StarredCount
import com.newsblur.network.APIConstants
import com.newsblur.network.APIManager
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.preference.PrefsRepo
import com.newsblur.service.NbSyncManager.UPDATE_DB_READY
import com.newsblur.service.NbSyncManager.UPDATE_METADATA
import com.newsblur.service.NbSyncManager.UPDATE_REBUILD
import com.newsblur.service.NbSyncManager.UPDATE_STATUS
import com.newsblur.service.NbSyncManager.UPDATE_STORY
import com.newsblur.service.NbSyncManager.submitError
import com.newsblur.service.NbSyncManager.submitUpdate
import com.newsblur.service.SyncServiceUtil.isStoryResponseGood
import com.newsblur.util.AppConstants
import com.newsblur.util.CursorFilters
import com.newsblur.util.FeedSet
import com.newsblur.util.FileCache
import com.newsblur.util.Log
import com.newsblur.util.NetworkUtils
import com.newsblur.util.NotificationUtils
import com.newsblur.util.ReadingAction
import com.newsblur.util.StateFilter
import com.newsblur.widget.WidgetUtils.hasActiveAppWidgets
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.util.Date
import javax.inject.Inject
import kotlin.coroutines.CoroutineContext

@AndroidEntryPoint
open class SyncService : JobService(), CoroutineScope {

    @Inject
    lateinit var apiManager: APIManager

    @Inject
    lateinit var dbHelper: BlurDatabaseHelper

    @IconFileCache
    @Inject
    lateinit var iconCache: FileCache

    @StoryImageCache
    @Inject
    lateinit var storyImageCache: FileCache

    @ThumbnailCache
    @Inject
    lateinit var thumbnailCache: FileCache

    @Inject
    lateinit var prefsRepo: PrefsRepo

    @Inject
    lateinit var syncServiceState: SyncServiceState

    private val serviceJob = SupervisorJob()
    private var mainJob: Job? = null

    override val coroutineContext: CoroutineContext =
            CoroutineName("SyncService") +
                    Dispatchers.IO +
                    serviceJob +
                    CoroutineExceptionHandler { context, throwable ->
                        Log.e("SyncService", "Coroutine exception on context $context with $throwable")
                    }

    private val delegate: SyncServiceDelegate = SyncServiceDelegateImpl(this)

    private val originalTextSubService = OriginalTextSubService(delegate)
    private val unreadsSubService = UnreadsSubService(delegate)
    private val imagePrefetchSubService = ImagePrefetchSubService(delegate)
    private val cleanupSubService = CleanupSubService(delegate)
    private val starredSubService = StarredSubService(delegate)

    private val orphanFeedIds = mutableSetOf<String>()
    private val disabledFeedIds = mutableSetOf<String>()

    /**
     * Kickoff hook for when we are started via a JobScheduler
     */
    override fun onStartJob(params: JobParameters?): Boolean {
        Log.d(this, "onStartJob")
        mainJob?.cancel()
        mainJob = launch { sync(); jobFinished(params, false) }
        return true // async
    }

    /**
     * Kickoff hook for when we are started via Context.startService()
     */
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(this, "onStartCommand")
        mainJob?.cancel()
        mainJob = launch { sync() }
        return START_NOT_STICKY
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        Log.d(this, "onStopJob")
        syncServiceState.setServiceState(ServiceState.Idle)
        mainJob?.cancel()
        mainJob = null
        return false
    }

    override fun onNetworkChanged(params: JobParameters) {
        super.onNetworkChanged(params)
        Log.d(this, "onNetworkChanged")
    }

    private suspend fun sync() = coroutineScope {
        Log.d(this, "Starting primary sync")
        ensureActive()

        housekeeping()
        ensureActive()

        // ping activities to indicate that housekeeping is done, and the DB is safe to use
        sendSyncUpdate(UPDATE_DB_READY)

        if (!NetworkUtils.isOnline(this@SyncService)) {
            Log.d(this.javaClass.name, "Skipping sync: device is offline")
            return@coroutineScope
        }

        if (!isAppForeground && !prefsRepo.isBackgroundNeeded(this@SyncService)) {
            Log.d(this.javaClass.name, "Skipping sync: device is in the background and background sync is disabled")
            return@coroutineScope
        }

        if (!isAppForeground && !prefsRepo.isBackgroundNetworkAllowed(this@SyncService)) {
            Log.d(this.javaClass.name, "Skipping sync: network type not appropriate for background sync.")
            return@coroutineScope
        }

        // async text requests might have been queued up and are being waiting on by the live UI. give them priority
        originalTextSubService.start(this)

        // first: catch up
        syncActions()

        // if MD is stale, sync it first so unreads don't get backwards with story unread state
        syncMetadata()

        // handle fetching of stories that are actively being requested by the live UI
        syncPendingFeedStories()

        // re-apply the local state of any actions executed before local UI interaction
        finishActions()

        // after all actions, double-check local state vs remote state consistency
        checkRecounts()

        // async story and image prefetch are lower priority and don't affect active reading, do them last
        unreadsSubService.start(this)
        imagePrefetchSubService.start(this)

        // almost all notifications will be pushed after the unreadsService gets new stories, but double-check
        // here in case some made it through the feed sync loop first
        pushNotifications()

        Log.d(this, "Finishing primary sync")

        syncServiceState.setServiceState(ServiceState.Idle)
    }

    override fun onDestroy() {
        Log.d(this, "onDestroy")
        syncServiceState.setServiceState(ServiceState.Idle)
        coroutineContext.cancel()
        super.onDestroy()
    }

    /**
     * Check for upgrades and wipe the DB if necessary and also does DB maintenance
     */
    private fun housekeeping() {
        try {
            val upgraded = prefsRepo.checkForUpgrade(this)
            if (upgraded) {
                syncServiceState.setServiceState(ServiceState.Housekeeping)
                sendSyncUpdate(UPDATE_STATUS or UPDATE_REBUILD)

                // wipe DB on first background run after upgrading
                // fist foreground run after upgrade will wipe db in InitActivity
                if (!isAppForeground) {
                    dbHelper.dropAndRecreateTables()
                }

                val appVersion = NbApplication.getVersion(this)
                prefsRepo.updateVersion(appVersion)
                // update user agent on api calls with latest app version
                val customUserAgent = NetworkUtils.getCustomUserAgent(appVersion)
                apiManager.updateCustomUserAgent(customUserAgent)
            }

            var autoVac = prefsRepo.isTimeToVacuum()
            // this will lock up the DB for a few seconds, only do it if the UI is hidden
            if (isAppForeground) autoVac = false

            if (upgraded || autoVac) {
                syncServiceState.setServiceState(ServiceState.Housekeeping)
                sendSyncUpdate(UPDATE_STATUS)
                Log.i(this.javaClass.name, "rebuilding DB . . .")
                dbHelper.vacuum()
                Log.i(this.javaClass.name, ". . . . done rebuilding DB")
                prefsRepo.updateLastVacuumTime()
            }
        } finally {
            sendSyncUpdate(UPDATE_METADATA)
        }
    }

    private fun syncActions() {
        if (backoffBackgroundCalls()) return

        var c: Cursor? = null
        try {
            c = dbHelper.getActions()
            syncServiceState.lastActionCount = c.count
            if (syncServiceState.lastActionCount < 1) return

            syncServiceState.setServiceState(ServiceState.ActionsSync)

            val stateFilter = prefsRepo.getStateFilter()

            actionsLoop@ while (c.moveToNext()) {
                sendSyncUpdate(UPDATE_STATUS)
                val id = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_ID))
                val ra: ReadingAction?
                try {
                    ra = ReadingAction.fromCursor(c)
                } catch (e: IllegalArgumentException) {
                    Log.e(this.javaClass.name, "error unfreezing ReadingAction", e)
                    dbHelper.clearAction(id)
                    continue@actionsLoop
                }

                // don't block story loading unless this is a brand new action
                if ((ra.tried > 0) && (syncServiceState.pendingFeed != null)) continue@actionsLoop

                Log.d(this, "attempting action: " + ra.toContentValues().toString())
                val response = ra.doRemote(apiManager, dbHelper, syncServiceState, stateFilter)

                if (response == null) {
                    Log.e(this.javaClass.name, "Discarding reading action with client-side error.")
                    dbHelper.clearAction(id)
                } else if (response.isProtocolError) {
                    // the network failed or we got a non-200, so be sure we retry
                    Log.i(this.javaClass.name, "Holding reading action with server-side or network error.")
                    dbHelper.incrementActionTried(id)
                    noteHardAPIFailure()
                    continue@actionsLoop
                } else if (response.isError()) {
                    // the API responds with a message either if the call was a client-side error or if it was handled in such a
                    // way that we should inform the user. in either case, it is considered complete.
                    Log.i(this.javaClass.name, "Discarding reading action with fatal message.")
                    dbHelper.clearAction(id)
                    val message = response.getErrorMessage(null)
                    if (message != null) sendToastError(message)
                } else {
                    // success!
                    dbHelper.clearAction(id)
                    syncServiceState.addFollowupAction(ra)
                    sendSyncUpdate(response.impactCode)
                }
                syncServiceState.lastActionCount--
            }
        } finally {
            BlurDatabaseHelper.closeQuietly(c)
            sendSyncUpdate(UPDATE_STATUS)
        }
    }

    /**
     * The very first step of a sync - get the feed/folder list, unread counts, and
     * unread hashes. Doing this resets pagination on the server!
     */
    private fun syncMetadata() {
        if (backoffBackgroundCalls()) return

        val untriedActions = dbHelper.getUntriedActionCount()
        if (untriedActions > 0) {
            Log.i(this.javaClass.name, "$untriedActions outstanding actions, yielding metadata sync")
            return
        }

        if (syncServiceState.doFeedsFolders || prefsRepo.isTimeToAutoSync()) {
            prefsRepo.updateLastSyncTime()
            syncServiceState.doFeedsFolders = false
        } else {
            return
        }

        Log.i(this.javaClass.name, "ready to sync feed list")

        syncServiceState.setServiceState(ServiceState.FolderFeedSync)
        sendSyncUpdate(UPDATE_STATUS)

        // there is an issue with feeds that have no folder or folders that list feeds that do not exist.  capture them for workarounds.
        val debugFeedIdsFromFolders = mutableSetOf<String>()
        val debugFeedIdsFromFeeds = mutableSetOf<String>()

        orphanFeedIds.clear()
        disabledFeedIds.clear()

        try {
            val feedResponse = apiManager.getFolderFeedMapping(true)

            if (feedResponse == null) {
                noteHardAPIFailure()
                return
            }

            if (!feedResponse.isAuthenticated) {
                // we should not have got this far without being logged in, so the server either
                // expired or ignored out cookie. keep track of this.
                syncServiceState.authFails += 1
                Log.w(this.javaClass.name, "Server ignored or rejected auth cookie.")
                if (syncServiceState.authFails >= AppConstants.MAX_API_TRIES) {
                    Log.w(this.javaClass.name, "too many auth fails, resetting cookie")
                    prefsRepo.logout(this, dbHelper)
                }
                syncServiceState.doFeedsFolders = true
                return
            } else {
                syncServiceState.authFails = 0
            }

            // a metadata sync invalidates pagination and feed status
            syncServiceState.clearExhaustedFeeds()
            syncServiceState.clearSeenFeedPages()
            syncServiceState.clearSeenFeedStories()
            UnreadsSubService.clear()
            syncServiceState.clearRecountCandidates()

            syncServiceState.lastFFConnMillis = feedResponse.connTime
            syncServiceState.lastFFReadMillis = feedResponse.readTime
            syncServiceState.lastFFParseMillis = feedResponse.parseTime
            val startTime = System.currentTimeMillis()

            prefsRepo.setPremium(feedResponse.isPremium, feedResponse.premiumExpire)
            prefsRepo.setArchive(feedResponse.isArchive, feedResponse.premiumExpire)
            prefsRepo.setIsStaff(feedResponse.isStaff)
            prefsRepo.setExtToken(feedResponse.shareExtToken)

            // note all feeds that belong to some folder so we can find orphans
            for (folder in feedResponse.folders) {
                debugFeedIdsFromFolders.addAll(folder.feedIds)
            }

            // data for the feeds table
            val feedValues = mutableListOf<ContentValues>()
            feedAddLoop@ for (feed in feedResponse.feeds) {
                // note all feeds for which the API returned data
                debugFeedIdsFromFeeds.add(feed.feedId)
                // sanity-check that the returned feeds actually exist in a folder or at the root
                // if they do not, they should neither display nor count towards unread numbers
                if (!debugFeedIdsFromFolders.contains(feed.feedId)) {
                    Log.w(this.javaClass.name, "Found and ignoring orphan feed (in feeds but not folders): " + feed.feedId)
                    orphanFeedIds.add(feed.feedId)
                    continue@feedAddLoop
                }
                if (!feed.active) {
                    // the feed is disabled/hidden, we don't want to fetch unreads
                    disabledFeedIds.add(feed.feedId)
                }
                feedValues.add(feed.getValues())
            }
            // also add the implied zero-id feed
            feedValues.add(Feed.getZeroFeed().getValues())

            // prune out missing feed IDs from folders
            for (id in debugFeedIdsFromFolders) {
                if (!debugFeedIdsFromFeeds.contains(id)) {
                    Log.w(this.javaClass.name, "Found and ignoring orphan feed (in folders but not feeds): $id")
                    orphanFeedIds.add(id)
                }
            }

            // data for the folder table
            val folderValues = mutableListOf<ContentValues>()
            val foldersSeen = mutableSetOf<String>()
            folderLoop@ for (folder in feedResponse.folders) {
                // don't form graph loops in the folder tree
                if (foldersSeen.contains(folder.name)) continue@folderLoop
                foldersSeen.add(folder.name)
                // prune out orphans before pushing to the DB
                folder.removeOrphanFeedIds(orphanFeedIds)
                folderValues.add(folder.getValues())
            }

            // data for the the social feeds table
            val socialFeedValues = mutableListOf<ContentValues>()
            for (feed in feedResponse.socialFeeds) {
                socialFeedValues.add(feed.getValues())
            }

            // populate the starred stories count table
            val starredCountValues = mutableListOf<ContentValues>()
            for (sc in feedResponse.starredCounts) {
                starredCountValues.add(sc.getValues())
            }

            // saved searches table
            val savedSearchesValues = mutableListOf<ContentValues>()
            for (savedSearch in feedResponse.savedSearches) {
                savedSearchesValues.add(savedSearch.getValues(dbHelper))
            }
            // the API vends the starred total as a different element, roll it into
            // the starred counts table using a special tag
            val totalStarred = StarredCount()
            totalStarred.count = feedResponse.starredCount
            totalStarred.tag = StarredCount.TOTAL_STARRED
            starredCountValues.add(totalStarred.getValues())

            dbHelper.setFeedsFolders(folderValues, feedValues, socialFeedValues, starredCountValues, savedSearchesValues)

            syncServiceState.lastFFWriteMillis = System.currentTimeMillis() - startTime
            syncServiceState.lastFeedCount = feedValues.size.toLong()

            Log.i(this.javaClass.name, "got feed list: " + syncServiceState.getSpeedInfo())

            unreadsSubService.doMetadata()
            unreadsSubService.start(this)
            cleanupSubService.start(this)
            starredSubService.start(this)
        } finally {
            sendSyncUpdate(UPDATE_METADATA or UPDATE_STATUS)
        }
    }

    /**
     * Fetch stories needed because the user is actively viewing a feed or folder.
     */
    private fun syncPendingFeedStories() {
        // track whether we actually tried to handle the feedset and found we had nothing
        // more to do, in which case we will clear it
        var finished = false

        val fs = syncServiceState.pendingFeed

        try {
            // see if we need to quickly reset fetch state for a feed. we
            // do this before the loop to prevent-mid loop state corruption
            synchronized(syncServiceState.resetFeedMutex) {
                syncServiceState.resetFeed?.let { resetFeed ->
                    Log.i(this.javaClass.name, "Resetting state for feed set: $resetFeed")
                    syncServiceState.removeFeedSetExhausted(resetFeed)
                    syncServiceState.removeFeedStoriesSeen(resetFeed)
                    syncServiceState.removeFeedPagesSeen(resetFeed)
                    syncServiceState.resetFeed = null
                    // a reset should also reset the stories table, just in case an async page of stories came in between the
                    // caller's (presumed) reset and our call ot prepareReadingSession(). unsetting the session feedset will
                    // cause the later call to prepareReadingSession() to do another reset
                    dbHelper.sessionFeedSet = null
                }
            }

            if (fs == null) {
                Log.d(this.javaClass.name, "No feed set to sync")
                return
            }

            prepareReadingSession(prefsRepo, dbHelper, fs)

            syncServiceState.lastFeedSet = fs

            if (syncServiceState.exhaustedFeeds.contains(fs)) {
                Log.i(this.javaClass.name, "No more stories for feed set: $fs")
                finished = true
                return
            }

            if (!syncServiceState.feedPagesSeen.containsKey(fs)) {
                syncServiceState.addFeedPagesSeen(fs, 0)
                syncServiceState.addFeedStoriesSeen(fs, 0)
                syncServiceState.workaroundReadStoryTimestamp = (Date()).time
                syncServiceState.workaroundGlobalSharedStoryTimestamp = (Date()).time
            }
            var pageNumber: Int = syncServiceState.feedPagesSeen[fs]!!
            var totalStoriesSeen: Int = syncServiceState.feedStoriesSeen[fs]!!

            val cursorFilters = CursorFilters(prefsRepo, fs)

            syncServiceState.setServiceState(ServiceState.StorySync)
            sendSyncUpdate(UPDATE_STATUS)

            ensureActive()
            while (isActive && totalStoriesSeen < syncServiceState.pendingFeedTarget) {

                // bail if the active view has changed
                if (fs != syncServiceState.pendingFeed) {
                    return
                }

                ensureActive()

                pageNumber++
                val apiResponse = apiManager.getStories(fs, pageNumber, cursorFilters.storyOrder, cursorFilters.readFilter, prefsRepo.getInfrequentCutoff())

                if (!isStoryResponseGood(apiResponse)) return

                if (fs != syncServiceState.pendingFeed) {
                    return
                }

                insertStories(apiResponse, fs, cursorFilters.stateFilter)
                // re-do any very recent actions that were incorrectly overwritten by this page
                finishActions()
                sendSyncUpdate(UPDATE_STORY or UPDATE_STATUS)

                syncServiceState.addFeedPagesSeen(fs, pageNumber)
                totalStoriesSeen += apiResponse.stories.size
                syncServiceState.addFeedStoriesSeen(fs, totalStoriesSeen)
                if (apiResponse.stories.size == 0) {
                    syncServiceState.addFeedSetExhausted(fs)
                    finished = true
                    return
                }

                // don't let the page loop block actions
                if (dbHelper.getUntriedActionCount() > 0) return
            }
            finished = true
        } finally {
            sendSyncUpdate(UPDATE_STATUS)
            synchronized(syncServiceState.pendingFeedMutex) {
                if (finished && fs == syncServiceState.pendingFeed) syncServiceState.pendingFeed = null
            }
        }
    }

    private fun insertStories(apiResponse: StoriesResponse, fs: FeedSet, stateFilter: StateFilter) {
        if (fs.isAllRead) {
            // Ugly Hack Warning: the API doesn't vend the sortation key necessary to display
            // stories when in the "read stories" view. It does, however, return them in the
            // correct order, so we can fudge a fake last-read-stamp so they will show up.
            // Stories read locally with have the correct stamp and show up fine. When local
            // and remote stories are integrated, the remote hack will override the ordering
            // so they get put into the correct sequence recorded by the API (the authority).
            for (story in apiResponse.stories) {
                // this fake TS was set when we fetched the first page. have it decrease as
                // we page through, so they append to the list as if most-recent-first.
                syncServiceState.workaroundReadStoryTimestamp--
                story.lastReadTimestamp = syncServiceState.workaroundReadStoryTimestamp
            }
        }

        if (fs.isGlobalShared) {
            // Ugly Hack Warning: the API doesn't vend the sortation key necessary to display
            // stories when in the "global shared stories" view. It does, however, return them
            // in the expected order, so we can fudge a fake shared-timestamp so they can be
            // selected from the DB in the same order.
            for (story in apiResponse.stories) {
                // this fake TS was set when we fetched the first page. have it decrease as
                // we page through, so they append to the list as if most-recent-first.
                syncServiceState.workaroundGlobalSharedStoryTimestamp--
                story.sharedTimestamp = syncServiceState.workaroundGlobalSharedStoryTimestamp
            }
        }

        if (fs.isInfrequent) {
            // the API vends a river of stories from sites that publish infrequently, but the
            // list of which feeds qualify is not vended. as a workaround, stories received
            // from this API are specially tagged so they can be displayed
            for (story in apiResponse.stories) {
                story.infrequent = true
            }
        }

        if (fs.isAllSaved || fs.isAllRead) {
            // Note: for reasons relating to the impl. of the web UI, the API returns incorrect
            // intel values for stories from these two APIs.  Fix them so they don't show green
            // when they really aren't.
            for (story in apiResponse.stories) {
                story.intelligence.intelligenceFeed--
            }
        }

        if (fs.getSingleSavedTag() != null) {
            // Workaround: the API doesn't vend an embedded 'feeds' block with metadata for feeds
            // to which the user is not subscribed but that contain saved stories. In order to
            // prevent these stories being invisible due to failed metadata joins, insert fake
            // feed data like with the zero-ID generic feed to match the web UI behaviour
            dbHelper.fixMissingStoryFeeds(apiResponse.stories)
        }

        if (fs.searchQuery != null) {
            // If this set of stories was found in response to the active search query, note
            // them as such in the DB so the UI can filter for them
            for (story in apiResponse.stories) {
                story.searchHit = fs.searchQuery
            }
        }

        Log.d(SyncService::class.java.name, "got stories from main fetch loop: " + apiResponse.stories.size)
        dbHelper.insertStories(apiResponse, stateFilter, true)
    }

    /**
     * Some actions have a final, local step after being done remotely to ensure in-flight
     * API actions didn't race-overwrite them.  Do these, and then clean up the DB.
     */
    private fun finishActions() {
        if (syncServiceState.followupActions.isEmpty()) return

        Log.d(this, "double-checking " + syncServiceState.followupActions.size + " actions")
        var impactFlags = 0
        for (ra in syncServiceState.followupActions) {
            val impact = ra.doLocal(dbHelper, prefsRepo, true)
            impactFlags = impactFlags or impact
        }
        sendSyncUpdate(impactFlags)

        // if there is a feed fetch loop running, don't clear, there will likely be races for
        // stories that were just tapped as they were being re-fetched
        synchronized(syncServiceState.pendingFeedMutex) {
            if (syncServiceState.pendingFeed != null) return
        }

        // if there is a what-is-unread sync in progress, hold off on confirming actions,
        // as this subservice can vend stale unread data
        if (unreadsSubService.isDoMetadata) return

        syncServiceState.clearFollowupActions()
    }

    fun prefetchImages(apiResponse: StoriesResponse) {
        storyLoop@ for (story in apiResponse.stories) {
            // only prefetch for unreads, so we don't grind to cache when the user scrolls
            // through old read stories
            if (story.read) continue@storyLoop
            // if the story provides known images we'll need for it, fetch those for offline reading
            if (story.imageUrls != null) {
                for (url in story.imageUrls) {
                    imagePrefetchSubService.addStoryUrl(url)
                }
            }
            if (story.thumbnailUrl != null) {
                imagePrefetchSubService.addThumbnailUrl(story.thumbnailUrl)
            }
        }
        imagePrefetchSubService.start(this)
    }

    /**
     * Prepare the reading session table to display the given feedset. This is done here
     * rather than in FeedUtils so we can track which FS is currently primed and not
     * constantly reset.  This is called not only when the UI wants to change out a
     * set but also when we sync a page of stories, since there are no guarantees which
     * will happen first.
     */
    fun prepareReadingSession(prefsRepo: PrefsRepo, dbHelper: BlurDatabaseHelper, fs: FeedSet) {
        synchronized(syncServiceState.pendingFeedMutex) {
            val cursorFilters = CursorFilters(prefsRepo, fs)
            if (fs != dbHelper.getSessionFeedSet()) {
                Log.d(SyncService::class.java.name, "preparing new reading session")
                // the next fetch will be the start of a new reading session; clear it so it
                // will be re-primed
                dbHelper.clearStorySession()
                // don't just rely on the auto-prepare code when fetching stories, it might be called
                // after we insert our first page and not trigger
                dbHelper.prepareReadingSession(fs, cursorFilters.stateFilter, cursorFilters.readFilter)
                // note which feed set we are loading so we can trigger another reset when it changes
                dbHelper.sessionFeedSet = fs
                submitUpdate(UPDATE_STORY or UPDATE_STATUS)
            }
        }
    }

    /**
     * See if any feeds have been touched in a way that require us to double-check unread counts;
     */
    private fun checkRecounts() {
        if (!syncServiceState.doFeedsFolders) return

        try {
            if (syncServiceState.recountCandidates.isEmpty()) return

            syncServiceState.setServiceState(ServiceState.RecountsSync)
            sendSyncUpdate(UPDATE_STATUS)

            // of all candidate feeds that were touched, now check to see if any
            // actually need their counts fetched
            val dirtySets = mutableSetOf<FeedSet>()
            for (fs in syncServiceState.recountCandidates) {
                // check for mismatched local and remote counts we need to reconcile
                if (dbHelper.getUnreadCount(fs, StateFilter.SOME) != dbHelper.getLocalUnreadCount(fs, StateFilter.SOME)) {
                    dirtySets.add(fs)
                }
                // check for feeds flagged for insta-fetch
                if (dbHelper.isFeedSetFetchPending(fs)) {
                    dirtySets.add(fs)
                }
            }
            if (dirtySets.isEmpty()) {
                syncServiceState.clearRecountCandidates()
                return
            }

            Log.i(this.javaClass.name, "recounting dirty feed sets: " + dirtySets.size)

            // if we are offline, the best we can do is perform a local unread recount and
            // save the true one for when we go back online.
            if (!NetworkUtils.isOnline(this)) {
                for (fs in syncServiceState.recountCandidates) {
                    dbHelper.updateLocalFeedCounts(fs)
                }
            } else {
                // if any reading activities are pending, it makes no sense to recount yet
                if (dbHelper.getUntriedActionCount() > 0) return

                val apiIds = mutableSetOf<String>()
                for (fs in syncServiceState.recountCandidates) {
                    apiIds.addAll(fs.getFlatFeedIds())
                }

                val apiResponse = apiManager.getFeedUnreadCounts(apiIds)
                if ((apiResponse == null) || (apiResponse.isError())) {
                    Log.w(this.javaClass.name, "Bad response to feed_unread_count")
                    return
                }
                if (apiResponse.feeds != null) {
                    for (entry in apiResponse.feeds.entries) {
                        dbHelper.updateFeedCounts(entry.key, entry.value.getValues())
                    }
                }
                if (apiResponse.socialFeeds != null) {
                    for (entry in apiResponse.socialFeeds.entries) {
                        val feedId = entry.key.replace(APIConstants.VALUE_PREFIX_SOCIAL.toRegex(), "")
                        dbHelper.updateSocialFeedCounts(feedId, entry.value.getValuesSocial())
                    }
                }
                syncServiceState.clearRecountCandidates()

                // if there was a mismatch, some stories might have been missed at the head of the
                // pagination loop, so reset it
                for (fs in dirtySets) {
                    syncServiceState.addFeedPagesSeen(fs, 0)
                    syncServiceState.addFeedStoriesSeen(fs, 0)
                }
            }
        } finally {
            sendSyncUpdate(UPDATE_METADATA or UPDATE_STATUS)
            syncServiceState.doFlushRecounts = false
        }
    }

    private fun backoffBackgroundCalls(): Boolean {
        if (isAppForeground) return false
        if (System.currentTimeMillis() > (syncServiceState.lastApiFailure + AppConstants.API_BACKGROUND_BACKOFF_MILLIS)) return false
        Log.i(this.javaClass.name, "abandoning background sync due to recent API failures.")
        return true
    }

    fun sendSyncUpdate(update: Int) {
        submitUpdate(update)
    }

    protected fun sendToastError(message: String) {
        submitError(message)
    }

    fun addImageUrlToPrefetch(url: String?) {
        imagePrefetchSubService.addStoryUrl(url)
    }

    private fun noteHardAPIFailure() {
        Log.w(this.javaClass.name, "hard API failure")
        syncServiceState.lastApiFailure = System.currentTimeMillis()
    }

    fun pushNotifications() {
        if (!prefsRepo.isEnableNotifications()) return

        // don't notify stories until the queue is flushed so they don't churn
        if (UnreadsSubService.storyHashQueue.isNotEmpty()) return
        // don't slow down active story loading
        if (syncServiceState.pendingFeed != null) return

        val cFocus = dbHelper.notifyFocusStoriesCursor
        val cUnread = dbHelper.notifyUnreadStoriesCursor
        NotificationUtils.notifyStories(this, cFocus, cUnread, iconCache, dbHelper)
        BlurDatabaseHelper.closeQuietly(cFocus)
        BlurDatabaseHelper.closeQuietly(cUnread)
    }

    fun isOrphanFeed(feedId: String): Boolean = orphanFeedIds.contains(feedId)

    fun isDisabledFeed(feedId: String): Boolean = disabledFeedIds.contains(feedId)

    companion object {

        fun stop(context: Context) {
            Log.i(SyncService::class.java.name, "Stop service")
            val stopIntent = Intent(context, SyncService::class.java)
            context.stopService(stopIntent)
        }
    }
}