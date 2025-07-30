package com.newsblur.service

import android.app.job.JobParameters
import android.app.job.JobService
import android.content.ContentValues
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
import com.newsblur.service.UnreadsService.Companion.doMetadata
import com.newsblur.service.UnreadsService.Companion.isDoMetadata
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
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.util.Date
import javax.inject.Inject
import kotlin.concurrent.Volatile
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

    override val coroutineContext: CoroutineContext =
            CoroutineName("SyncService") +
                    Dispatchers.IO +
                    SupervisorJob() +
                    CoroutineExceptionHandler { context, throwable ->
                        Log.e("SyncService", "Coroutine exception on context $context with $throwable")
                    }

    private val originalTextSubService = OriginalTextSubService(this)
    private val unreadsSubService = UnreadsSubService(this)
    private val imagePrefetchSubService = ImagePrefetchSubService(this)

    // TODO revisit this
    val orphanFeedIds = mutableSetOf<String>()
    val disabledFeedIds = mutableSetOf<String>()

    /**
     * Kickoff hook for when we are started via a JobScheduler
     */
    override fun onStartJob(params: JobParameters?): Boolean {
        Log.d(this, "onStartJob")
        launch {
            try {
                sync()
            } finally {
                jobFinished(params, false)
            }
        }
        return true // async
    }

    /**
     * Kickoff hook for when we are started via Context.startService()
     */
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(this, "onStartCommand")
        launch { sync() }
        return START_NOT_STICKY
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        Log.d(this, "onStopJob")
        coroutineContext.cancel()
        return false
    }

    override fun onNetworkChanged(params: JobParameters) {
        super.onNetworkChanged(params)
        Log.d(this, "onNetworkChanged")
    }

    private suspend fun sync() {
        Log.d(this, "Starting primary sync")

        housekeeping()

        if (!NetworkUtils.isOnline(this)) {
            Log.d(this, "Skipping sync: device is offline")
            return
        }

        // TODO revisit this check
        if (!(isAppForeground ||
                        prefsRepo.isEnableNotifications() ||
                        prefsRepo.isBackgroundNetworkAllowed(this) ||
                        hasActiveAppWidgets(this))) {
            Log.d(this.javaClass.name, "Skipping sync: app not active and network type not appropriate for background sync.")
            return
        }


        // ping activities to indicate that housekeeping is done, and the DB is safe to use
        sendSyncUpdate(UPDATE_DB_READY)

        // async text requests might have been queued up and are being waiting on by the live UI. give them priority
        originalTextSubService.start()

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
        unreadsSubService.start()
        imagePrefetchSubService.start()

        // almost all notifications will be pushed after the unreadsService gets new stories, but double-check
        // here in case some made it through the feed sync loop first
        pushNotifications()

        Log.d(this, "Finishing primary sync")
    }

    override fun onDestroy() {
        Log.d(this, "onDestroy")
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
//                NBSyncService.HousekeepingRunning = true
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
//                NBSyncService.HousekeepingRunning = true
//                sendSyncUpdate(UPDATE_STATUS)
                Log.i(this.javaClass.name, "rebuilding DB . . .")
                dbHelper.vacuum()
                Log.i(this.javaClass.name, ". . . . done rebuilding DB")
                prefsRepo.updateLastVacuumTime()
            }
        } finally {
//            if (NBSyncService.HousekeepingRunning) {
//                NBSyncService.HousekeepingRunning = false
            sendSyncUpdate(UPDATE_METADATA)
//            }
        }
    }

    private fun syncActions() {
        if (backoffBackgroundCalls()) return

        var c: Cursor? = null
        try {
            c = dbHelper.getActions()
            lastActionCount = c.count
            if (lastActionCount < 1) return

//            NBSyncService.ActionsRunning = true

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
                if ((ra.tried > 0) && (PendingFeed != null)) continue@actionsLoop

                Log.d(this, "attempting action: " + ra.toContentValues().toString())
                val response = ra.doRemote(apiManager, dbHelper, stateFilter)

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
                    FollowupActions.add(ra)
                    sendSyncUpdate(response.impactCode)
                }
                lastActionCount--
            }
        } finally {
            BlurDatabaseHelper.closeQuietly(c)
//            NBSyncService.ActionsRunning = false
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

        if (DoFeedsFolders || prefsRepo.isTimeToAutoSync()) {
            prefsRepo.updateLastSyncTime()
            DoFeedsFolders = false
        } else {
            return
        }

        Log.i(this.javaClass.name, "ready to sync feed list")

        FFSyncRunning = true // TODO remove?
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
                NBSyncService.authFails += 1
                Log.w(this.javaClass.name, "Server ignored or rejected auth cookie.")
                if (NBSyncService.authFails >= AppConstants.MAX_API_TRIES) {
                    Log.w(this.javaClass.name, "too many auth fails, resetting cookie")
                    prefsRepo.logout(this, dbHelper)
                }
                DoFeedsFolders = true
                return
            } else {
                NBSyncService.authFails = 0
            }

            // a metadata sync invalidates pagination and feed status
            ExhaustedFeeds.clear()
            FeedPagesSeen.clear()
            FeedStoriesSeen.clear()
//            clear() // TODO UnreadService.clear()
            RecountCandidates.clear()

            lastFFConnMillis = feedResponse.connTime
            lastFFReadMillis = feedResponse.readTime
            lastFFParseMillis = feedResponse.parseTime
            val startTime = System.currentTimeMillis()

            prefsRepo.setPremium(feedResponse.isPremium, feedResponse.premiumExpire)
            prefsRepo.setArchive(feedResponse.isArchive, feedResponse.premiumExpire)
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

            lastFFWriteMillis = System.currentTimeMillis() - startTime
            lastFeedCount = feedValues.size.toLong()

            Log.i(this.javaClass.name, "got feed list: " + NBSyncService.getSpeedInfo())

            doMetadata()
//            unreadsService.start() // TODO
//            cleanupService.start() // TODO
//            starredService.start() // TODO
        } finally {
            FFSyncRunning = false
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

        val fs = PendingFeed

        try {
            // see if we need to quickly reset fetch state for a feed. we
            // do this before the loop to prevent-mid loop state corruption
            synchronized(MUTEX_ResetFeed) {
                if (ResetFeed != null) {
                    Log.i(this.javaClass.name, "Resetting state for feed set: $ResetFeed")
                    ExhaustedFeeds.remove(ResetFeed)
                    FeedStoriesSeen.remove(ResetFeed)
                    FeedPagesSeen.remove(ResetFeed)
                    ResetFeed = null
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

            LastFeedSet = fs

            if (ExhaustedFeeds.contains(fs)) {
                Log.i(this.javaClass.name, "No more stories for feed set: $fs")
                finished = true
                return
            }

            if (!FeedPagesSeen.containsKey(fs)) {
                FeedPagesSeen.put(fs, 0)
                FeedStoriesSeen.put(fs, 0)
                workaroundReadStoryTimestamp = (Date()).time
                workaroundGlobalSharedStoryTimestamp = (Date()).time
            }
            var pageNumber: Int = FeedPagesSeen[fs]!!
            var totalStoriesSeen: Int = FeedStoriesSeen[fs]!!

            val cursorFilters = CursorFilters(prefsRepo, fs)

//            StorySyncRunning = true
            sendSyncUpdate(UPDATE_STATUS)

            while (totalStoriesSeen < PendingFeedTarget) {
                // this is a good heuristic for double-checking if we have left the story list
                if (FlushRecounts) return

                // bail if the active view has changed
                if (fs != PendingFeed) {
                    return
                }

                pageNumber++
                val apiResponse = apiManager.getStories(fs, pageNumber, cursorFilters.storyOrder, cursorFilters.readFilter, prefsRepo.getInfrequentCutoff())

                if (!isStoryResponseGood(apiResponse)) return

                if (fs != PendingFeed) {
                    return
                }

                insertStories(apiResponse, fs, cursorFilters.stateFilter)
                // re-do any very recent actions that were incorrectly overwritten by this page
                finishActions()
                sendSyncUpdate(UPDATE_STORY or UPDATE_STATUS)

                FeedPagesSeen.put(fs, pageNumber)
                totalStoriesSeen += apiResponse.stories.size
                FeedStoriesSeen.put(fs, totalStoriesSeen)
                if (apiResponse.stories.size == 0) {
                    ExhaustedFeeds.add(fs)
                    finished = true
                    return
                }

                // don't let the page loop block actions
                if (dbHelper.getUntriedActionCount() > 0) return
            }
            finished = true
        } finally {
//            NBSyncService.StorySyncRunning = false
            sendSyncUpdate(UPDATE_STATUS)
            synchronized(PENDING_FEED_MUTEX) {
                if (finished && fs == PendingFeed) PendingFeed = null
            }
        }
    }

    fun insertStories(apiResponse: StoriesResponse, stateFilter: StateFilter) {
        Log.d(NBSyncService::class.java.name, "got stories from sub sync: " + apiResponse.stories.size)
        dbHelper.insertStories(apiResponse, stateFilter, false)
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
                workaroundReadStoryTimestamp--
                story.lastReadTimestamp = workaroundReadStoryTimestamp
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
                workaroundGlobalSharedStoryTimestamp--
                story.sharedTimestamp = workaroundGlobalSharedStoryTimestamp
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

        Log.d(NBSyncService::class.java.name, "got stories from main fetch loop: " + apiResponse.stories.size)
        dbHelper.insertStories(apiResponse, stateFilter, true)
    }

    /**
     * Some actions have a final, local step after being done remotely to ensure in-flight
     * API actions didn't race-overwrite them.  Do these, and then clean up the DB.
     */
    private fun finishActions() {
        if (FollowupActions.isEmpty()) return

        Log.d(this, "double-checking " + FollowupActions.size + " actions")
        var impactFlags = 0
        for (ra in FollowupActions) {
            val impact = ra.doLocal(dbHelper, prefsRepo, true)
            impactFlags = impactFlags or impact
        }
        sendSyncUpdate(impactFlags)

        // if there is a feed fetch loop running, don't clear, there will likely be races for
        // stories that were just tapped as they were being re-fetched
        synchronized(PENDING_FEED_MUTEX) {
            if (PendingFeed != null) return
        }

        // if there is a what-is-unread sync in progress, hold off on confirming actions,
        // as this subservice can vend stale unread data
        if (isDoMetadata) return

        FollowupActions.clear()
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
        imagePrefetchSubService.start()
    }

    /**
     * Prepare the reading session table to display the given feedset. This is done here
     * rather than in FeedUtils so we can track which FS is currently primed and not
     * constantly reset.  This is called not only when the UI wants to change out a
     * set but also when we sync a page of stories, since there are no guarantees which
     * will happen first.
     */
    fun prepareReadingSession(prefsRepo: PrefsRepo, dbHelper: BlurDatabaseHelper, fs: FeedSet) {
        synchronized(PENDING_FEED_MUTEX) {
            val cursorFilters = CursorFilters(prefsRepo, fs)
            if (fs != dbHelper.getSessionFeedSet()) {
                Log.d(NBSyncService::class.java.name, "preparing new reading session")
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
        if (!FlushRecounts) return

        try {
            if (RecountCandidates.isEmpty()) return

//            NBSyncService.RecountsRunning = true
            sendSyncUpdate(UPDATE_STATUS)

            // of all candidate feeds that were touched, now check to see if any
            // actually need their counts fetched
            val dirtySets = mutableSetOf<FeedSet>()
            for (fs in RecountCandidates) {
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
                RecountCandidates.clear()
                return
            }

            Log.i(this.javaClass.name, "recounting dirty feed sets: " + dirtySets.size)

            // if we are offline, the best we can do is perform a local unread recount and
            // save the true one for when we go back online.
            if (!NetworkUtils.isOnline(this)) {
                for (fs in RecountCandidates) {
                    dbHelper.updateLocalFeedCounts(fs)
                }
            } else {
                // if any reading activities are pending, it makes no sense to recount yet
                if (dbHelper.getUntriedActionCount() > 0) return

                val apiIds = mutableSetOf<String>()
                for (fs in RecountCandidates) {
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
                RecountCandidates.clear()

                // if there was a mismatch, some stories might have been missed at the head of the
                // pagination loop, so reset it
                for (fs in dirtySets) {
                    FeedPagesSeen.put(fs, 0)
                    FeedStoriesSeen.put(fs, 0)
                }
            }
        } finally {
//            if (NBSyncService.RecountsRunning) {
//                NBSyncService.RecountsRunning = false
            sendSyncUpdate(UPDATE_METADATA or UPDATE_STATUS)
//            }
            FlushRecounts = false
        }
    }

    private fun backoffBackgroundCalls(): Boolean {
        if (isAppForeground) return false
        if (System.currentTimeMillis() > (lastAPIFailure + AppConstants.API_BACKGROUND_BACKOFF_MILLIS)) return false
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
        lastAPIFailure = System.currentTimeMillis()
    }

    fun pushNotifications() {
        if (!prefsRepo.isEnableNotifications()) return

        // don't notify stories until the queue is flushed so they don't churn
        if (UnreadsSubService.storyHashQueue.isNotEmpty()) return
        // don't slow down active story loading
        if (PendingFeed != null) return

        val cFocus = dbHelper.notifyFocusStoriesCursor
        val cUnread = dbHelper.notifyUnreadStoriesCursor
        NotificationUtils.notifyStories(this, cFocus, cUnread, iconCache, dbHelper)
        BlurDatabaseHelper.closeQuietly(cFocus)
        BlurDatabaseHelper.closeQuietly(cUnread)
    }

    /**
     * Requests that the service fetch additional stories for the specified feed/folder. Returns
     * true if more will be fetched as a result of this request.
     *
     * @param desiredStoryCount the minimum number of stories to fetch.
     * @param callerSeen        the number of stories the caller thinks they have seen for the FeedSet
     * or a negative number if the caller trusts us to track for them, or null if the caller
     * has ambiguous or no state about the FeedSet and wants us to refresh for them.
     */
    fun requestMoreForFeed(fs: FeedSet, desiredStoryCount: Int, callerSeen: Int?): Boolean {
        synchronized(PENDING_FEED_MUTEX) {
            if (ExhaustedFeeds.contains(fs) && (fs == LastFeedSet && (callerSeen != null))) {
                android.util.Log.d(NBSyncService::class.java.name, "rejecting request for feedset that is exhaused")
                return false
            }
            var alreadyPending = 0
            if (fs == PendingFeed) alreadyPending = PendingFeedTarget
            var alreadySeen = FeedStoriesSeen.get(fs)
            if (alreadySeen == null) alreadySeen = 0
            if ((callerSeen != null) && (callerSeen < alreadySeen)) {
                // the caller is probably filtering and thinks they have fewer than we do, so
                // update our count to agree with them, and force-allow another requet
                alreadySeen = callerSeen
                FeedStoriesSeen.put(fs, callerSeen)
                alreadyPending = 0
            }

            PendingFeed = fs
            PendingFeedTarget = desiredStoryCount

            if (fs != LastFeedSet) {
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

    /**
     * Resets any internal temp vars or queues. Called when switching accounts.
     */
    fun clearState() {
        PendingFeed = null
        ResetFeed = null
        FollowupActions.clear()
        RecountCandidates.clear()
        ExhaustedFeeds.clear()
        FeedPagesSeen.clear()
        FeedStoriesSeen.clear()
        originalTextSubService.clear()
        unreadsSubService.clear()
        imagePrefetchSubService.clear()
    }

    companion object {
        /**
         * The time of the last hard API failure we encountered. Used to implement back-off so that the sync
         * service doesn't spin in the background chewing up battery when the API is unavailable.
         */
        private var lastAPIFailure: Long = 0
        private var lastActionCount: Int = 0

        /**
         * Feed set that we need to sync immediately for the UI.
         */
        private val MUTEX_ResetFeed: Any = Any()
        private var PendingFeed: FeedSet? = null
        private var PendingFeedTarget: Int = 0
        private val PENDING_FEED_MUTEX: Any = Any()

        /**
         * Feed to reset to zero-state, so it is fetched fresh, presumably with new filters.
         */
        private var ResetFeed: FeedSet? = null

        /**
         * Actions that may need to be double-checked locally due to overlapping API calls.
         */
        private val FollowupActions = mutableListOf<ReadingAction>()

        @Volatile
        private var DoFeedsFolders: Boolean = false

        @Volatile
        private var FFSyncRunning: Boolean = false

        /**
         * Feed sets that the API has said to have no more pages left.
         */
        private val ExhaustedFeeds = mutableSetOf<FeedSet>()

        /**
         * The number of pages we have collected for the given feed set.
         */
        private val FeedPagesSeen = mutableMapOf<FeedSet, Int>()

        /**
         * The number of stories we have collected for the given feed set.
         */
        private val FeedStoriesSeen = mutableMapOf<FeedSet, Int>()

        /**
         * Feed IDs (API stype) that have been acted upon and need a double-check for counts.
         */
        private val RecountCandidates = mutableSetOf<FeedSet>()

        /**
         * The last feed set that was actually fetched from the API.
         */
        private var LastFeedSet: FeedSet? = null

        private var lastFeedCount: Long = 0L
        private var lastFFConnMillis: Long = 0L
        private var lastFFReadMillis: Long = 0L
        private var lastFFParseMillis: Long = 0L
        private var lastFFWriteMillis: Long = 0L

        private var workaroundReadStoryTimestamp: Long = 0
        private var workaroundGlobalSharedStoryTimestamp: Long = 0

        @Volatile
        private var FlushRecounts: Boolean = false

        /**
         * Force a refresh of feed/folder data on the next sync, even if enough time
         * hasn't passed for an autosync.
         */
        fun forceFeedsFolders() {
            DoFeedsFolders = true
        }

        fun flushRecounts() {
            FlushRecounts = true
        }

        /**
         * Is there a sync for a given FeedSet running?
         */
        fun isFeedSetSyncing(fs: FeedSet): Boolean {
//            return (fs == PendingFeed && (!NBSyncService.stopSync(context))) // TODO
            return fs == PendingFeed // TODO
        }
    }
}