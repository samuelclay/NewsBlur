package com.newsblur.service;

import android.app.Service;
import android.app.job.JobParameters;
import android.app.job.JobService;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.os.Process;

import com.newsblur.NbApplication;
import com.newsblur.R;
import com.newsblur.database.BlurDatabaseHelper;
import static com.newsblur.database.BlurDatabaseHelper.closeQuietly;
import static com.newsblur.service.NBSyncReceiver.UPDATE_DB_READY;
import static com.newsblur.service.NBSyncReceiver.UPDATE_METADATA;
import static com.newsblur.service.NBSyncReceiver.UPDATE_REBUILD;
import static com.newsblur.service.NBSyncReceiver.UPDATE_STATUS;
import static com.newsblur.service.NBSyncReceiver.UPDATE_STORY;

import androidx.annotation.NonNull;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.di.IconFileCache;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Folder;
import com.newsblur.domain.SavedSearch;
import com.newsblur.domain.SocialFeed;
import com.newsblur.domain.StarredCount;
import com.newsblur.domain.Story;
import com.newsblur.network.APIConstants;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.FeedFolderResponse;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.network.domain.UnreadCountResponse;
import com.newsblur.util.AppConstants;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FileCache;
import com.newsblur.util.Log;
import com.newsblur.util.NetworkUtils;
import com.newsblur.util.NotificationUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadingAction;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StateFilter;
import com.newsblur.util.StoryOrder;
import com.newsblur.widget.WidgetUtils;

import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.TimeUnit;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

/**
 * A background service to handle synchronisation with the NB servers.
 *
 * It is the design goal of this service to handle all communication with the API.
 * Activities and fragments should enqueue actions in the DB or use the methods
 * provided herein to request an action and let the service handle things.
 *
 * Per the contract of the Service class, at most one instance shall be created. It
 * will be preserved and re-used where possible.  Additionally, regularly scheduled
 * invocations are requested via the Main activity and BootReceiver.
 *
 * The service will notify all running activities of an update before, during, and
 * after sync operations are performed.  Activities can then refresh views and
 * query this class to see if progress indicators should be active.
 */
@AndroidEntryPoint
public class NBSyncService extends JobService {

    private static final Object COMPLETION_CALLBACKS_MUTEX = new Object();
    private static final Object PENDING_FEED_MUTEX = new Object();

    private volatile static boolean ActionsRunning = false;
    private volatile static boolean FFSyncRunning = false;
    private volatile static boolean StorySyncRunning = false;
    private volatile static boolean HousekeepingRunning = false;
    private volatile static boolean RecountsRunning = false;

    private volatile static boolean DoFeedsFolders = false;
    private volatile static boolean DoUnreads = false;
    private volatile static boolean HaltNow = false;

    /** Informational flag only, as to whether we were offline last time we cycled. */
    public volatile static boolean OfflineNow = false;

    public volatile static int authFails = 0;
    public volatile static Boolean isPremium = null;
    public volatile static Boolean isStaff = null;

    private static long lastFeedCount = 0L;
    private static long lastFFConnMillis = 0L;
    private static long lastFFReadMillis = 0L;
    private static long lastFFParseMillis = 0L;
    private static long lastFFWriteMillis = 0L;

    /** Feed set that we need to sync immediately for the UI. */
    private static FeedSet PendingFeed;
    private static Integer PendingFeedTarget = 0;

    /** The last feed set that was actually fetched from the API. */
    private static FeedSet LastFeedSet;

    /** Feed sets that the API has said to have no more pages left. */
    private static Set<FeedSet> ExhaustedFeeds;
    static { ExhaustedFeeds = new HashSet<FeedSet>(); }
    /** The number of pages we have collected for the given feed set. */
    private static Map<FeedSet,Integer> FeedPagesSeen;
    static { FeedPagesSeen = new HashMap<FeedSet,Integer>(); }
    /** The number of stories we have collected for the given feed set. */
    private static Map<FeedSet,Integer> FeedStoriesSeen;
    static { FeedStoriesSeen = new HashMap<FeedSet,Integer>(); }

    /** Feed to reset to zero-state, so it is fetched fresh, presumably with new filters. */
    private static FeedSet ResetFeed;

    private static final Object MUTEX_ResetFeed = new Object();

    /** Actions that may need to be double-checked locally due to overlapping API calls. */
    private static List<ReadingAction> FollowupActions;
    static { FollowupActions = new ArrayList<ReadingAction>(); }

    /** Feed IDs (API stype) that have been acted upon and need a double-check for counts. */
    private static Set<FeedSet> RecountCandidates;
    static { RecountCandidates = new HashSet<FeedSet>(); }
    private volatile static boolean FlushRecounts = false;

    Set<String> orphanFeedIds = new HashSet<String>();
    Set<String> disabledFeedIds = new HashSet<String>();

    private ExecutorService primaryExecutor;
    private List<Integer> outstandingStartIds = new ArrayList<Integer>();
    private List<JobParameters> outstandingStartParams = new ArrayList<JobParameters>();
    private boolean mainSyncRunning = false;
    CleanupService cleanupService;
    StarredService starredService;
    OriginalTextService originalTextService;
    UnreadsService unreadsService;
    ImagePrefetchService imagePrefetchService;
    private boolean forceHalted = false;

    @Inject
	APIManager apiManager;

    @Inject
    BlurDatabaseHelper dbHelper;

    @IconFileCache
    @Inject
    FileCache iconCache;

    /** The time of the last hard API failure we encountered. Used to implement back-off so that the sync
        service doesn't spin in the background chewing up battery when the API is unavailable. */
    private static long lastAPIFailure = 0;

    private static int lastActionCount = 0;

	@Override
	public void onCreate() {
		super.onCreate();
        com.newsblur.util.Log.d(this, "onCreate");
        HaltNow = false;
        primaryExecutor = Executors.newFixedThreadPool(1);
	}

    /**
     * Services can be constructed synchrnously by the Main thread, so don't do expensive
     * parts of construction in onCreate, but save them for when we are in our own thread.
     */
    private void finishConstruction() {
        if (cleanupService == null || imagePrefetchService == null) {
            cleanupService = new CleanupService(this);
            starredService = new StarredService(this);
            originalTextService = new OriginalTextService(this);
            unreadsService = new UnreadsService(this);
            imagePrefetchService = new ImagePrefetchService(this);
            com.newsblur.util.Log.offerContext(this);
        }
    }

    /**
     * Kickoff hook for when we are started via Context.startService()
     */
    @Override
    public int onStartCommand(Intent intent, int flags, final int startId) {
        com.newsblur.util.Log.d(this, "onStartCommand");
        // only perform a sync if the app is actually running or background syncs are enabled
        if (NbApplication.isAppForeground() || PrefsUtils.isBackgroundNeeded(this)) {
            HaltNow = false;
            // Services actually get invoked on the main system thread, and are not
            // allowed to do tangible work.  We spawn a thread to do so.
            Runnable r = new Runnable() {
                public void run() {
                    mainSyncRunning = true;
                    doSync();
                    mainSyncRunning = false;
                    // record the startId so when the sync thread and all sub-service threads finish,
                    // we can report that this invocation completed.
                    synchronized (COMPLETION_CALLBACKS_MUTEX) {outstandingStartIds.add(startId);}
                    checkCompletion();
                }
            };
            primaryExecutor.execute(r);
        } else {
            com.newsblur.util.Log.i(this, "Skipping sync: app not active and background sync not enabled.");
            synchronized (COMPLETION_CALLBACKS_MUTEX) {outstandingStartIds.add(startId);}
            checkCompletion();
        } 
        // indicate to the system that the service should be alive when started, but
        // needn't necessarily persist under memory pressure
        return Service.START_NOT_STICKY;
    }

    /**
     * Kickoff hook for when we are started via a JobScheduler
     */
    @Override
    public boolean onStartJob(final JobParameters params) {
        com.newsblur.util.Log.d(this, "onStartJob");
        // only perform a sync if the app is actually running or background syncs are enabled
        if (NbApplication.isAppForeground() || PrefsUtils.isBackgroundNeeded(this)) {
            HaltNow = false;
            // Services actually get invoked on the main system thread, and are not
            // allowed to do tangible work.  We spawn a thread to do so.
            Runnable r = new Runnable() {
                public void run() {
                    mainSyncRunning = true;
                    doSync();
                    mainSyncRunning = false;
                    // record the JobParams so when the sync thread and all sub-service threads finish,
                    // we can report that this invocation completed.
                    synchronized (COMPLETION_CALLBACKS_MUTEX) {outstandingStartParams.add(params);}
                    checkCompletion();
                }
            };
            primaryExecutor.execute(r);
        } else {
            com.newsblur.util.Log.d(this, "Skipping sync: app not active and background sync not enabled.");
            synchronized (COMPLETION_CALLBACKS_MUTEX) {outstandingStartParams.add(params);}
            checkCompletion();
        } 
        return true; // indicate that we are async
    }

    @Override
    public boolean onStopJob(JobParameters params) {
        com.newsblur.util.Log.d(this, "onStopJob");
        HaltNow = true;
        // return false to indicate that we don't necessarily need re-invocation ahead of schedule.
        // background syncs can pick up where the last one left off and forground syncs aren't
        // run via cancellable JobScheduler invocations.
        return false;
    }

    /**
     * Do the actual work of syncing.
     */
    private synchronized void doSync() {
        try {
            if (HaltNow) return;

            finishConstruction();

            Log.d(this, "starting primary sync");

            if (!NbApplication.isAppForeground()) {
                // if the UI isn't running, politely run at background priority
                Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND);
            } else {
                // if the UI is running, run just one step below normal priority so we don't step on async tasks that are updating the UI
                Process.setThreadPriority(Process.THREAD_PRIORITY_DEFAULT + Process.THREAD_PRIORITY_LESS_FAVORABLE);
            }

            Thread.currentThread().setName(this.getClass().getName());

            if (OfflineNow) {
                if (NetworkUtils.isOnline(this)) {
                    OfflineNow = false;   
                    sendSyncUpdate(UPDATE_STATUS);
                } else {
                    com.newsblur.util.Log.d(this, "Abandoning sync: network still offline");
                    return;
                }
            }

            // do this even if background syncs aren't enabled, because it absolutely must happen
            // on all devices
            housekeeping();

            // check to see if we are on an allowable network only after ensuring we have CPU
            if (!( NbApplication.isAppForeground() ||
                   PrefsUtils.isEnableNotifications(this) || 
                   PrefsUtils.isBackgroundNetworkAllowed(this) ||
                    WidgetUtils.hasActiveAppWidgets(this)) ) {
                Log.d(this.getClass().getName(), "Abandoning sync: app not active and network type not appropriate for background sync.");
                return;
            }

            // ping activities to indicate that housekeeping is done, and the DB is safe to use
            sendSyncUpdate(UPDATE_DB_READY);

            // async text requests might have been queued up and are being waiting on by the live UI. give them priority
            originalTextService.start();

            // first: catch up
            syncActions();

            // if MD is stale, sync it first so unreads don't get backwards with story unread state
            syncMetadata();
            
            // handle fetching of stories that are actively being requested by the live UI
            syncPendingFeedStories();

            // re-apply the local state of any actions executed before local UI interaction
            finishActions();

            // after all actions, double-check local state vs remote state consistency
            checkRecounts();

            // async story and image prefetch are lower priority and don't affect active reading, do them last
            unreadsService.start();
            imagePrefetchService.start();

            // almost all notifications will be pushed after the unreadsService gets new stories, but double-check
            // here in case some made it through the feed sync loop first
            pushNotifications();

            Log.d(this, "finishing primary sync");

        } catch (Exception e) {
            com.newsblur.util.Log.e(this.getClass().getName(), "Sync error.", e);
        } 
    }

    /**
     * Check for upgrades and wipe the DB if necessary, and do DB maintenance
     */
    private void housekeeping() {
        try {
            boolean upgraded = PrefsUtils.checkForUpgrade(this);
            if (upgraded) {
                HousekeepingRunning = true;
                sendSyncUpdate(UPDATE_STATUS | UPDATE_REBUILD);
                // wipe the local DB if this is a first background run. if this is a first foreground
                // run, InitActivity will have wiped for us
                if (!NbApplication.isAppForeground()) {
                    dbHelper.dropAndRecreateTables();
                }
                // in case this is the first time we have run since moving the cache to the new location,
                // blow away the old version entirely. This line can be removed some time well after
                // v61+ is widely deployed
                FileCache.cleanUpOldCache1(this);
                FileCache.cleanUpOldCache2(this);
                String appVersion = PrefsUtils.getVersion(this);
                PrefsUtils.updateVersion(this, appVersion);
                // update user agent on api calls with latest app version
                String customUserAgent = NetworkUtils.getCustomUserAgent(appVersion);
                apiManager.updateCustomUserAgent(customUserAgent);
            }

            boolean autoVac = PrefsUtils.isTimeToVacuum(this);
            // this will lock up the DB for a few seconds, only do it if the UI is hidden
            if (NbApplication.isAppForeground()) autoVac = false;
            
            if (upgraded || autoVac) {
                HousekeepingRunning = true;
                sendSyncUpdate(UPDATE_STATUS);
                com.newsblur.util.Log.i(this.getClass().getName(), "rebuilding DB . . .");
                dbHelper.vacuum();
                com.newsblur.util.Log.i(this.getClass().getName(), ". . . . done rebuilding DB");
                PrefsUtils.updateLastVacuumTime(this);
            }
        } finally {
            if (HousekeepingRunning) {
                HousekeepingRunning = false;
                sendSyncUpdate(UPDATE_METADATA);
            }
        }
    }

    /**
     * Perform any reading actions the user has done before we do anything else.
     */
    private void syncActions() {
        if (stopSync()) return;
        if (backoffBackgroundCalls()) return;

        Cursor c = null;
        try {
            c = dbHelper.getActions();
            lastActionCount = c.getCount();
            if (lastActionCount < 1) return;

            ActionsRunning = true;

            actionsloop : while (c.moveToNext()) {
                sendSyncUpdate(UPDATE_STATUS);
                String id = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_ID));
                ReadingAction ra;
                try {
                    ra = ReadingAction.fromCursor(c);
                } catch (IllegalArgumentException e) {
                    com.newsblur.util.Log.e(this.getClass().getName(), "error unfreezing ReadingAction", e);
                    dbHelper.clearAction(id);
                    continue actionsloop;
                }

                // don't block story loading unless this is a brand new action
                if ((ra.getTried() > 0) && (PendingFeed != null)) continue actionsloop;
                    
                com.newsblur.util.Log.d(this, "attempting action: " + ra.toContentValues().toString());
                NewsBlurResponse response = ra.doRemote(apiManager, dbHelper);

                if (response == null) {
                    com.newsblur.util.Log.e(this.getClass().getName(), "Discarding reading action with client-side error.");
                    dbHelper.clearAction(id);
                } else if (response.isProtocolError) {
                    // the network failed or we got a non-200, so be sure we retry
                    com.newsblur.util.Log.i(this.getClass().getName(), "Holding reading action with server-side or network error.");
                    dbHelper.incrementActionTried(id);
                    noteHardAPIFailure();
                    continue actionsloop;
                } else if (response.isError()) {
                    // the API responds with a message either if the call was a client-side error or if it was handled in such a
                    // way that we should inform the user. in either case, it is considered complete.
                    com.newsblur.util.Log.i(this.getClass().getName(), "Discarding reading action with fatal message.");
                    dbHelper.clearAction(id);
                    String message = response.getErrorMessage(null);
                    if (message != null) sendToastError(message);
                } else {
                    // success!
                    dbHelper.clearAction(id);
                    FollowupActions.add(ra);
                    sendSyncUpdate(response.impactCode);
                }
                lastActionCount--;
            }
        } finally {
            closeQuietly(c);
            ActionsRunning = false;
            sendSyncUpdate(UPDATE_STATUS);
        }
    }

    /**
     * Some actions have a final, local step after being done remotely to ensure in-flight
     * API actions didn't race-overwrite them.  Do these, and then clean up the DB.
     */
    private void finishActions() {
        if (HaltNow) return;
        if (FollowupActions.size() < 1) return;

        Log.d(this, "double-checking " + FollowupActions.size() + " actions");
        int impactFlags = 0;
        for (ReadingAction ra : FollowupActions) {
            int impact = ra.doLocal(dbHelper, true);
            impactFlags |= impact;
        }
        sendSyncUpdate(impactFlags);

        // if there is a feed fetch loop running, don't clear, there will likely be races for
        // stories that were just tapped as they were being re-fetched
        synchronized (PENDING_FEED_MUTEX) {if (PendingFeed != null) return;}

        // if there is a what-is-unread sync in progress, hold off on confirming actions,
        // as this subservice can vend stale unread data
        if (UnreadsService.isDoMetadata()) return;

        FollowupActions.clear();
    }

    /**
     * The very first step of a sync - get the feed/folder list, unread counts, and
     * unread hashes. Doing this resets pagination on the server!
     */
    private void syncMetadata() {
        if (stopSync()) return;
        if (backoffBackgroundCalls()) return;
        int untriedActions = dbHelper.getUntriedActionCount();
        if (untriedActions > 0) {
            com.newsblur.util.Log.i(this.getClass().getName(), untriedActions + " outstanding actions, yielding metadata sync");
            return;
        }

        if (DoFeedsFolders || PrefsUtils.isTimeToAutoSync(this)) {
            PrefsUtils.updateLastSyncTime(this);
            DoFeedsFolders = false;
        } else {
            return;
        }

        com.newsblur.util.Log.i(this.getClass().getName(), "ready to sync feed list");

        FFSyncRunning = true;
        sendSyncUpdate(UPDATE_STATUS);

        // there is an issue with feeds that have no folder or folders that list feeds that do not exist.  capture them for workarounds.
        Set<String> debugFeedIdsFromFolders = new HashSet<String>();
        Set<String> debugFeedIdsFromFeeds = new HashSet<String>();
        orphanFeedIds = new HashSet<String>();
        disabledFeedIds = new HashSet<String>();

        try {
            FeedFolderResponse feedResponse = apiManager.getFolderFeedMapping(true);

            if (feedResponse == null) {
                noteHardAPIFailure();
                return;
            }

            if (! feedResponse.isAuthenticated) {
                // we should not have got this far without being logged in, so the server either
                // expired or ignored out cookie. keep track of this.
                authFails += 1;
                com.newsblur.util.Log.w(this.getClass().getName(), "Server ignored or rejected auth cookie.");
                if (authFails >= AppConstants.MAX_API_TRIES) {
                    com.newsblur.util.Log.w(this.getClass().getName(), "too many auth fails, resetting cookie");
                    PrefsUtils.logout(this, dbHelper);
                }
                DoFeedsFolders = true;
                return;
            } else {
                authFails = 0;
            }

            if (HaltNow) return;

            // a metadata sync invalidates pagination and feed status
            ExhaustedFeeds.clear();
            FeedPagesSeen.clear();
            FeedStoriesSeen.clear();
            UnreadsService.clear();
            RecountCandidates.clear();

            lastFFConnMillis = feedResponse.connTime;
            lastFFReadMillis = feedResponse.readTime;
            lastFFParseMillis = feedResponse.parseTime;
            long startTime = System.currentTimeMillis();

            isPremium = feedResponse.isPremium;
            isStaff = feedResponse.isStaff;

            PrefsUtils.setPremium(this, feedResponse.isPremium, feedResponse.premiumExpire);

            // note all feeds that belong to some folder so we can find orphans
            for (Folder folder : feedResponse.folders) {
                debugFeedIdsFromFolders.addAll(folder.feedIds);
            }

            // data for the feeds table
            List<ContentValues> feedValues = new ArrayList<ContentValues>();
            feedaddloop: for (Feed feed : feedResponse.feeds) {
                // note all feeds for which the API returned data
                debugFeedIdsFromFeeds.add(feed.feedId);
                // sanity-check that the returned feeds actually exist in a folder or at the root
                // if they do not, they should neither display nor count towards unread numbers
                if (! debugFeedIdsFromFolders.contains(feed.feedId)) {
                    Log.w(this.getClass().getName(), "Found and ignoring orphan feed (in feeds but not folders): " + feed.feedId );
                    orphanFeedIds.add(feed.feedId);
                    continue feedaddloop;
                }
                if (! feed.active) {
                    // the feed is disabled/hidden, we don't want to fetch unreads
                    disabledFeedIds.add(feed.feedId);
                }
                feedValues.add(feed.getValues());
            }
            // also add the implied zero-id feed
            feedValues.add(Feed.getZeroFeed().getValues());

            // prune out missing feed IDs from folders
            for (String id : debugFeedIdsFromFolders) {
                if (! debugFeedIdsFromFeeds.contains(id)) {
                    Log.w(this.getClass().getName(), "Found and ignoring orphan feed (in folders but not feeds): " + id );
                    orphanFeedIds.add(id);
                }
            }
            
            // data for the folder table
            List<ContentValues> folderValues = new ArrayList<ContentValues>();
            Set<String> foldersSeen = new HashSet<String>(feedResponse.folders.size());
            folderloop: for (Folder folder : feedResponse.folders) {
                // don't form graph loops in the folder tree
                if (foldersSeen.contains(folder.name)) continue folderloop;
                foldersSeen.add(folder.name);
                // prune out orphans before pushing to the DB
                folder.removeOrphanFeedIds(orphanFeedIds);
                folderValues.add(folder.getValues());
            }

            // data for the the social feeds table
            List<ContentValues> socialFeedValues = new ArrayList<ContentValues>();
            for (SocialFeed feed : feedResponse.socialFeeds) {
                socialFeedValues.add(feed.getValues());
            }
            
            // populate the starred stories count table
            List<ContentValues> starredCountValues = new ArrayList<ContentValues>();
            for (StarredCount sc : feedResponse.starredCounts) {
                starredCountValues.add(sc.getValues());
            }

            // saved searches table
            List<ContentValues> savedSearchesValues = new ArrayList<>();
            for (SavedSearch savedSearch : feedResponse.savedSearches) {
                savedSearchesValues.add(savedSearch.getValues(dbHelper));
            }
            // the API vends the starred total as a different element, roll it into
            // the starred counts table using a special tag
            StarredCount totalStarred = new StarredCount();
            totalStarred.count = feedResponse.starredCount;
            totalStarred.tag = StarredCount.TOTAL_STARRED;
            starredCountValues.add(totalStarred.getValues());

            dbHelper.setFeedsFolders(folderValues, feedValues, socialFeedValues, starredCountValues, savedSearchesValues);

            lastFFWriteMillis = System.currentTimeMillis() - startTime;
            lastFeedCount = feedValues.size();

            com.newsblur.util.Log.i(this.getClass().getName(), "got feed list: " + getSpeedInfo());

            UnreadsService.doMetadata();
            unreadsService.start();
            cleanupService.start();
            starredService.start();

        } finally {
            FFSyncRunning = false;
            sendSyncUpdate(UPDATE_METADATA | UPDATE_STATUS);
        }

    }

    /**
     * See if any feeds have been touched in a way that require us to double-check unread counts;
     */
    private void checkRecounts() {
        if (!FlushRecounts) return;

        try {
            if (RecountCandidates.size() < 1) return;

            RecountsRunning = true;
            sendSyncUpdate(UPDATE_STATUS);

            // of all candidate feeds that were touched, now check to see if any
            // actually need their counts fetched
            Set<FeedSet> dirtySets = new HashSet<FeedSet>();
            for (FeedSet fs : RecountCandidates) {
                // check for mismatched local and remote counts we need to reconcile
                if (dbHelper.getUnreadCount(fs, StateFilter.SOME) != dbHelper.getLocalUnreadCount(fs, StateFilter.SOME)) {
                    dirtySets.add(fs);
                }
                // check for feeds flagged for insta-fetch
                if (dbHelper.isFeedSetFetchPending(fs)) {
                    dirtySets.add(fs);
                }
            }
            if (dirtySets.size() < 1) {
                RecountCandidates.clear();
                return;
            }

            com.newsblur.util.Log.i(this.getClass().getName(), "recounting dirty feed sets: " + dirtySets.size());

            // if we are offline, the best we can do is perform a local unread recount and
            // save the true one for when we go back online.
            if (!NetworkUtils.isOnline(this)) {
                for (FeedSet fs : RecountCandidates) {
                    dbHelper.updateLocalFeedCounts(fs);
                }
            } else {
                if (stopSync()) return;
                // if any reading activities are pending, it makes no sense to recount yet
                if (dbHelper.getUntriedActionCount() > 0) return;

                Set<String> apiIds = new HashSet<String>();
                for (FeedSet fs : RecountCandidates) {
                    apiIds.addAll(fs.getFlatFeedIds());
                }

                UnreadCountResponse apiResponse = apiManager.getFeedUnreadCounts(apiIds);
                if ((apiResponse == null) || (apiResponse.isError())) {
                    com.newsblur.util.Log.w(this.getClass().getName(), "Bad response to feed_unread_count");
                    return;
                }
                if (apiResponse.feeds != null ) {
                    for (Map.Entry<String,UnreadCountResponse.UnreadMD> entry : apiResponse.feeds.entrySet()) {
                        dbHelper.updateFeedCounts(entry.getKey(), entry.getValue().getValues());
                    }
                }
                if (apiResponse.socialFeeds != null ) {
                    for (Map.Entry<String,UnreadCountResponse.UnreadMD> entry : apiResponse.socialFeeds.entrySet()) {
                        String feedId = entry.getKey().replaceAll(APIConstants.VALUE_PREFIX_SOCIAL, "");
                        dbHelper.updateSocialFeedCounts(feedId, entry.getValue().getValuesSocial());
                    }
                }
                RecountCandidates.clear();

                // if there was a mismatch, some stories might have been missed at the head of the
                // pagination loop, so reset it
                for (FeedSet fs : dirtySets) {
                    FeedPagesSeen.put(fs, 0);
                    FeedStoriesSeen.put(fs, 0);
                }
            }
        } finally {
            if (RecountsRunning) {
                RecountsRunning = false;
                sendSyncUpdate(UPDATE_METADATA | UPDATE_STATUS);
            }
            FlushRecounts = false;
        }
    }

    /**
     * Fetch stories needed because the user is actively viewing a feed or folder.
     */
    private void syncPendingFeedStories() {
        // track whether we actually tried to handle the feedset and found we had nothing
        // more to do, in which case we will clear it
        boolean finished = false;

        FeedSet fs = PendingFeed;

        try {
            // see if we need to quickly reset fetch state for a feed. we
            // do this before the loop to prevent-mid loop state corruption
            synchronized (MUTEX_ResetFeed) {
                if (ResetFeed != null) {
                    com.newsblur.util.Log.i(this.getClass().getName(), "Resetting state for feed set: " + ResetFeed);
                    ExhaustedFeeds.remove(ResetFeed);
                    FeedStoriesSeen.remove(ResetFeed);
                    FeedPagesSeen.remove(ResetFeed);
                    ResetFeed = null;
                    // a reset should also reset the stories table, just in case an async page of stories came in between the
                    // caller's (presumed) reset and our call ot prepareReadingSession(). unsetting the session feedset will
                    // cause the later call to prepareReadingSession() to do another reset
                    dbHelper.setSessionFeedSet(null);
                }
            }

            if (fs == null) {
                com.newsblur.util.Log.d(this.getClass().getName(), "No feed set to sync");
                return;
            }

            prepareReadingSession(dbHelper, fs);

            LastFeedSet = fs;
            
            if (ExhaustedFeeds.contains(fs)) {
                com.newsblur.util.Log.i(this.getClass().getName(), "No more stories for feed set: " + fs);
                finished = true;
                return;
            }
            
            if (!FeedPagesSeen.containsKey(fs)) {
                FeedPagesSeen.put(fs, 0);
                FeedStoriesSeen.put(fs, 0);
                workaroundReadStoryTimestamp = (new Date()).getTime();
                workaroundGloblaSharedStoryTimestamp = (new Date()).getTime();
            }
            int pageNumber = FeedPagesSeen.get(fs);
            int totalStoriesSeen = FeedStoriesSeen.get(fs);

            StoryOrder order = PrefsUtils.getStoryOrder(this, fs);
            ReadFilter filter = PrefsUtils.getReadFilter(this, fs);

            StorySyncRunning = true;
            sendSyncUpdate(UPDATE_STATUS);

            while (totalStoriesSeen < PendingFeedTarget) {
                if (stopSync()) return;
                // this is a good heuristic for double-checking if we have left the story list
                if (FlushRecounts) return;

                // bail if the active view has changed
                if (!fs.equals(PendingFeed)) {
                    return; 
                }

                pageNumber++;
                StoriesResponse apiResponse = apiManager.getStories(fs, pageNumber, order, filter);
            
                if (! isStoryResponseGood(apiResponse)) return;

                if (!fs.equals(PendingFeed)) {
                    return; 
                }

                insertStories(apiResponse, fs);
                // re-do any very recent actions that were incorrectly overwritten by this page
                finishActions();
                sendSyncUpdate(UPDATE_STORY | UPDATE_STATUS);

                prefetchOriginalText(apiResponse);
            
                FeedPagesSeen.put(fs, pageNumber);
                totalStoriesSeen += apiResponse.stories.length;
                FeedStoriesSeen.put(fs, totalStoriesSeen);
                if (apiResponse.stories.length == 0) {
                    ExhaustedFeeds.add(fs);
                    finished = true;
                    return;
                }

                // don't let the page loop block actions
                if (dbHelper.getUntriedActionCount() > 0) return;
            }
            finished = true;

        } finally {
            StorySyncRunning = false;
            sendSyncUpdate(UPDATE_STATUS);
            synchronized (PENDING_FEED_MUTEX) {
                if (finished && fs.equals(PendingFeed)) PendingFeed = null;
            }
        }
    }

    private boolean isStoryResponseGood(StoriesResponse response) {
        if (response == null) {
            com.newsblur.util.Log.e(this.getClass().getName(), "Null response received while loading stories.");
            return false;
        }
        if (response.stories == null) {
            com.newsblur.util.Log.e(this.getClass().getName(), "Null stories member received while loading stories.");
            return false;
        }
        return true;
    }

    private long workaroundReadStoryTimestamp;
    private long workaroundGloblaSharedStoryTimestamp;

    private void insertStories(StoriesResponse apiResponse, FeedSet fs) {
        if (fs.isAllRead()) {
            // Ugly Hack Warning: the API doesn't vend the sortation key necessary to display
            // stories when in the "read stories" view. It does, however, return them in the
            // correct order, so we can fudge a fake last-read-stamp so they will show up.
            // Stories read locally with have the correct stamp and show up fine. When local
            // and remote stories are integrated, the remote hack will override the ordering
            // so they get put into the correct sequence recorded by the API (the authority).
            for (Story story : apiResponse.stories) {
                // this fake TS was set when we fetched the first page. have it decrease as
                // we page through, so they append to the list as if most-recent-first.
                workaroundReadStoryTimestamp --;
                story.lastReadTimestamp = workaroundReadStoryTimestamp;
            }
        }

        if (fs.isGlobalShared()) {
            // Ugly Hack Warning: the API doesn't vend the sortation key necessary to display
            // stories when in the "global shared stories" view. It does, however, return them
            // in the expected order, so we can fudge a fake shared-timestamp so they can be
            // selected from the DB in the same order.
            for (Story story : apiResponse.stories) {
                // this fake TS was set when we fetched the first page. have it decrease as
                // we page through, so they append to the list as if most-recent-first.
                workaroundGloblaSharedStoryTimestamp --;
                story.sharedTimestamp = workaroundGloblaSharedStoryTimestamp;
            }
        }

        if (fs.isInfrequent()) {
            // the API vends a river of stories from sites that publish infrequently, but the
            // list of which feeds qualify is not vended. as a workaround, stories received
            // from this API are specially tagged so they can be displayed
            for (Story story : apiResponse.stories) {
                story.infrequent = true;
            }
        }

        if (fs.isAllSaved() || fs.isAllRead()) {
            // Note: for reasons relating to the impl. of the web UI, the API returns incorrect
            // intel values for stories from these two APIs.  Fix them so they don't show green
            // when they really aren't.
            for (Story story : apiResponse.stories) {
                story.intelligence.intelligenceFeed--;
            }
        }

        if (fs.getSingleSavedTag() != null) {
            // Workaround: the API doesn't vend an embedded 'feeds' block with metadata for feeds
            // to which the user is not subscribed but that contain saved stories. In order to
            // prevent these stories being invisible due to failed metadata joins, insert fake
            // feed data like with the zero-ID generic feed to match the web UI behaviour
            dbHelper.fixMissingStoryFeeds(apiResponse.stories);
        }

        if (fs.getSearchQuery() != null) {
            // If this set of stories was found in response to the active search query, note
            // them as such in the DB so the UI can filter for them
            for (Story story : apiResponse.stories) {
                story.searchHit = fs.getSearchQuery();
            }
        }

        com.newsblur.util.Log.d(NBSyncService.class.getName(), "got stories from main fetch loop: " + apiResponse.stories.length);
        dbHelper.insertStories(apiResponse, true);
    }

    void insertStories(StoriesResponse apiResponse) {
        com.newsblur.util.Log.d(NBSyncService.class.getName(), "got stories from sub sync: " + apiResponse.stories.length);
        dbHelper.insertStories(apiResponse, false);
    }

    void prefetchOriginalText(StoriesResponse apiResponse) {
        storyloop: for (Story story : apiResponse.stories) {
            // only prefetch for unreads, so we don't grind to cache when the user scrolls
            // through old read stories
            if (story.read) continue storyloop;
            // if the feed is viewed in text mode by default, fetch that for offline reading
            DefaultFeedView mode = PrefsUtils.getDefaultViewModeForFeed(this, story.feedId);
            if (mode == DefaultFeedView.TEXT) {
                if (dbHelper.getStoryText(story.storyHash) == null) {
                    originalTextService.addHash(story.storyHash);
                }
            }
        }
        originalTextService.start();
    }

    void prefetchImages(StoriesResponse apiResponse) {
        storyloop: for (Story story : apiResponse.stories) {
            // only prefetch for unreads, so we don't grind to cache when the user scrolls
            // through old read stories
            if (story.read) continue storyloop;
            // if the story provides known images we'll need for it, fetch those for offline reading
            if (story.imageUrls != null) {
                for (String url : story.imageUrls) {
                    imagePrefetchService.addUrl(url);
                }
            }
            if (story.thumbnailUrl != null) {
                imagePrefetchService.addThumbnailUrl(story.thumbnailUrl);
            }
        }
        imagePrefetchService.start();
    }

    void pushNotifications() {
        if (! PrefsUtils.isEnableNotifications(this)) return;

        // don't notify stories until the queue is flushed so they don't churn
        if (unreadsService.StoryHashQueue.size() > 0) return;
        // don't slow down active story loading
        if (PendingFeed != null) return;

        Cursor cFocus = dbHelper.getNotifyFocusStoriesCursor();
        Cursor cUnread = dbHelper.getNotifyUnreadStoriesCursor();
        NotificationUtils.notifyStories(this, cFocus, cUnread, iconCache, dbHelper);
        closeQuietly(cFocus);
        closeQuietly(cUnread);
    }

    /**
     * Check to see if all async sync tasks have completed, indicating that sync can me marked as
     * complete.  Call this any time any individual sync task finishes.
     */
    void checkCompletion() {
        //Log.d(this, "checking completion");
        if (mainSyncRunning) return;
        if ((cleanupService != null) && cleanupService.isRunning()) return;
        if ((starredService != null) && starredService.isRunning()) return;
        if ((originalTextService != null) && originalTextService.isRunning()) return;
        if ((unreadsService != null) && unreadsService.isRunning()) return;
        if ((imagePrefetchService != null) && imagePrefetchService.isRunning()) return;
        Log.d(this, "confirmed completion");
        // iff all threads have finished, mark all received work as completed
        synchronized (COMPLETION_CALLBACKS_MUTEX) {
            for (JobParameters params : outstandingStartParams) {
                jobFinished(params, forceHalted);
            }
            for (Integer startId : outstandingStartIds) {
                stopSelf(startId);
            }
            outstandingStartIds.clear();
            outstandingStartParams.clear();
        }
    }

    static boolean stopSync(Context context) {
        if (HaltNow) {
            com.newsblur.util.Log.i(NBSyncService.class.getName(), "stopping sync, soft interrupt set.");
            return true;
        }
        if (context == null) return false;
        if (!NetworkUtils.isOnline(context)) {
            OfflineNow = true;
            return true;
        }
        return false;
    }

    boolean stopSync() {
        return stopSync(this);
    }

    private void noteHardAPIFailure() {
        com.newsblur.util.Log.w(this.getClass().getName(), "hard API failure");
        lastAPIFailure = System.currentTimeMillis();
    }

    private boolean backoffBackgroundCalls() {
        if (NbApplication.isAppForeground()) return false;
        if (System.currentTimeMillis() > (lastAPIFailure + AppConstants.API_BACKGROUND_BACKOFF_MILLIS)) return false;
        com.newsblur.util.Log.i(this.getClass().getName(), "abandoning background sync due to recent API failures.");
        return true;
    }

    /**
     * Is the main feed/folder list sync running and blocking?
     */
    public static boolean isFeedFolderSyncRunning() {
        return (HousekeepingRunning || FFSyncRunning);
    }

    public static boolean isFeedCountSyncRunning() {
        return (HousekeepingRunning || RecountsRunning || FFSyncRunning);
    }

    public static boolean isHousekeepingRunning() {
        return HousekeepingRunning;
    }

    /**
     * Is there a sync for a given FeedSet running?
     */
    public static boolean isFeedSetSyncing(FeedSet fs, Context context) {
        return (fs.equals(PendingFeed) && (!stopSync(context)));
    }

    public static boolean isFeedSetExhausted(FeedSet fs) {
        return ExhaustedFeeds.contains(fs);
    }

    public static boolean isFeedSetStoriesFresh(FeedSet fs) {
        Integer count = FeedStoriesSeen.get(fs);
        if (count == null) return false;
        if (count < 1) return false;
        return true;
    }

    public static String getSyncStatusMessage(Context context, boolean brief) {
        if (OfflineNow) return context.getResources().getString(R.string.sync_status_offline);
        if (HousekeepingRunning) return context.getResources().getString(R.string.sync_status_housekeeping);
        if (FFSyncRunning) return context.getResources().getString(R.string.sync_status_ffsync);
        if (CleanupService.activelyRunning) return context.getResources().getString(R.string.sync_status_cleanup);
        if (StarredService.activelyRunning) return context.getResources().getString(R.string.sync_status_starred);
        if (brief && !AppConstants.VERBOSE_LOG) return null;
        if (ActionsRunning) return String.format(context.getResources().getString(R.string.sync_status_actions), lastActionCount);
        if (RecountsRunning) return context.getResources().getString(R.string.sync_status_recounts);
        if (StorySyncRunning) return context.getResources().getString(R.string.sync_status_stories);
        if (UnreadsService.activelyRunning) return String.format(context.getResources().getString(R.string.sync_status_unreads), UnreadsService.getPendingCount());
        if (OriginalTextService.activelyRunning) return String.format(context.getResources().getString(R.string.sync_status_text), OriginalTextService.getPendingCount());
        if (ImagePrefetchService.activelyRunning) return String.format(context.getResources().getString(R.string.sync_status_images), ImagePrefetchService.getPendingCount());
        return null;
    }

    /**
     * Force a refresh of feed/folder data on the next sync, even if enough time
     * hasn't passed for an autosync.
     */
    public static void forceFeedsFolders() {
        DoFeedsFolders = true;
    }

    public static void flushRecounts() {
        FlushRecounts = true;
    }

    /**
     * Requests that the service fetch additional stories for the specified feed/folder. Returns
     * true if more will be fetched as a result of this request.
     *
     * @param desiredStoryCount the minimum number of stories to fetch.
     * @param callerSeen the number of stories the caller thinks they have seen for the FeedSet
     *        or a negative number if the caller trusts us to track for them, or null if the caller
     *        has ambiguous or no state about the FeedSet and wants us to refresh for them.
     */
    public static boolean requestMoreForFeed(FeedSet fs, int desiredStoryCount, Integer callerSeen) {
        synchronized (PENDING_FEED_MUTEX) {
            if (ExhaustedFeeds.contains(fs) && (fs.equals(LastFeedSet) && (callerSeen != null))) {
                android.util.Log.d(NBSyncService.class.getName(), "rejecting request for feedset that is exhaused");
                return false;
            }
            Integer alreadyPending = 0;
            if (fs.equals(PendingFeed)) alreadyPending = PendingFeedTarget;
            Integer alreadySeen = FeedStoriesSeen.get(fs);
            if (alreadySeen == null) alreadySeen = 0;
            if ((callerSeen != null) && (callerSeen < alreadySeen)) {
                // the caller is probably filtering and thinks they have fewer than we do, so
                // update our count to agree with them, and force-allow another requet
                alreadySeen = callerSeen;
                FeedStoriesSeen.put(fs, callerSeen);
                alreadyPending = 0;
            }

            PendingFeed = fs;
            PendingFeedTarget = desiredStoryCount;

            //Log.d(NBSyncService.class.getName(), "callerhas: " + callerSeen + "  have:" + alreadySeen + "  want:" + desiredStoryCount + "  pending:" + alreadyPending);

            if (!fs.equals(LastFeedSet)) {
                return true;
            }
            if (desiredStoryCount <= alreadySeen) {
                return false;
            }
            if (desiredStoryCount <= alreadyPending) {
                return false;
            }
            
        }
        return true;
    }

    /**
     * Prepare the reading session table to display the given feedset. This is done here
     * rather than in FeedUtils so we can track which FS is currently primed and not
     * constantly reset.  This is called not only when the UI wants to change out a
     * set but also when we sync a page of stories, since there are no guarantees which
     * will happen first.
     */
    public static void prepareReadingSession(BlurDatabaseHelper dbHelper, FeedSet fs) {
        synchronized (PENDING_FEED_MUTEX) {
            if (! fs.equals(dbHelper.getSessionFeedSet())) {
                com.newsblur.util.Log.d(NBSyncService.class.getName(), "preparing new reading session");
                // the next fetch will be the start of a new reading session; clear it so it
                // will be re-primed
                dbHelper.clearStorySession();
                // don't just rely on the auto-prepare code when fetching stories, it might be called
                // after we insert our first page and not trigger
                dbHelper.prepareReadingSession(fs);
                // note which feedset we are loading so we can trigger another reset when it changes
                dbHelper.setSessionFeedSet(fs);
                dbHelper.sendSyncUpdate(UPDATE_STORY | UPDATE_STATUS);
            }
        }
    }

    /**
     * Gracefully stop the loading of the current FeedSet and unset the current story session
     * so it will get reset before any further stories are fetched.
     */
    public static void resetReadingSession(BlurDatabaseHelper dbHelper) {
        com.newsblur.util.Log.d(NBSyncService.class.getName(), "requesting reading session reset");
        synchronized (PENDING_FEED_MUTEX) {
            PendingFeed = null;
            dbHelper.setSessionFeedSet(null);
        }
    }

    /**
     * Reset the API pagniation state for the given feedset, presumably because the order or filter changed.
     */
    public static void resetFetchState(FeedSet fs) {
        synchronized (MUTEX_ResetFeed) {
            com.newsblur.util.Log.d(NBSyncService.class.getName(), "requesting feed fetch state reset");
            ResetFeed = fs;
        }
    }

    public static void addRecountCandidates(FeedSet fs) {
        if (fs == null) return;
        // if this is a special feedset (read, saved, global shared, etc) that doesn't represent a
        // countable set of stories, don't bother recounting it
        if (fs.getFlatFeedIds().size() < 1) return;
        RecountCandidates.add(fs);
    }

    public static void addRecountCandidates(Set<FeedSet> sets) {
        for (FeedSet fs : sets) {
            addRecountCandidates(fs);
        }
    }

    public static void softInterrupt() {
        com.newsblur.util.Log.i(NBSyncService.class.getName(), "soft stop");
        HaltNow = true;
    }

    /**
     * Resets any internal temp vars or queues. Called when switching accounts.
     */
    public static void clearState() {
        PendingFeed = null;
        ResetFeed = null;
        FollowupActions.clear();
        RecountCandidates.clear();
        ExhaustedFeeds.clear();
        FeedPagesSeen.clear();
        FeedStoriesSeen.clear();
        OriginalTextService.clear();
        UnreadsService.clear();
        ImagePrefetchService.clear();
    }

    @Override
    public void onDestroy() {
        try {
            com.newsblur.util.Log.d(this, "onDestroy");
            synchronized (COMPLETION_CALLBACKS_MUTEX) {
                if ((outstandingStartIds.size() > 0) || (outstandingStartParams.size() > 0)) {
                    com.newsblur.util.Log.w(this, "Service scheduler destroyed before all jobs marked done?");
                }
            }
            if (cleanupService != null) cleanupService.shutdown();
            if (unreadsService != null) unreadsService.shutdown();
            if (starredService != null) starredService.shutdown();
            if (originalTextService != null) originalTextService.shutdown();
            if (imagePrefetchService != null) imagePrefetchService.shutdown();
            if (primaryExecutor != null) {
                primaryExecutor.shutdown();
                try {
                    primaryExecutor.awaitTermination(AppConstants.SHUTDOWN_SLACK_SECONDS, TimeUnit.SECONDS);
                } catch (InterruptedException e) {
                    primaryExecutor.shutdownNow();
                    Thread.currentThread().interrupt();
                }
            }
            com.newsblur.util.Log.d(this, "onDestroy done");
        } catch (Exception ex) {
            com.newsblur.util.Log.e(this, "unclean shutdown", ex);
        }
        super.onDestroy();
    }

    public static String getSpeedInfo() {
        StringBuilder s = new StringBuilder();
        s.append(lastFeedCount).append(" feeds in ");
        s.append(" conn:").append(lastFFConnMillis);
        s.append(" read:").append(lastFFReadMillis);
        s.append(" parse:").append(lastFFParseMillis);
        s.append(" store:").append(lastFFWriteMillis);
        return s.toString();
    }

    public static String getPendingInfo() {
        StringBuilder s = new StringBuilder();
        s.append(" pre:").append(lastActionCount);
        s.append(" post:").append(FollowupActions.size());
        return s.toString();
    }

    protected void sendSyncUpdate(int update) {
        Intent i = new Intent(NBSyncReceiver.NB_SYNC_ACTION);
        i.putExtra(NBSyncReceiver.NB_SYNC_UPDATE_TYPE, update);
        broadcastSync(i);
    }

    protected void sendToastError(@NonNull String message) {
        Intent i = new Intent(NBSyncReceiver.NB_SYNC_ACTION);
        i.putExtra(NBSyncReceiver.NB_SYNC_ERROR_MESSAGE, message);
        broadcastSync(i);
    }

    private void broadcastSync(@NonNull Intent intent) {
        if (NbApplication.isAppForeground()) {
            sendBroadcast(intent);
        }
    }
}
