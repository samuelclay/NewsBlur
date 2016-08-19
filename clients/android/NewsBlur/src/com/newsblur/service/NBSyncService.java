package com.newsblur.service;

import android.app.Service;
import android.content.ComponentCallbacks2;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.os.IBinder;
import android.os.PowerManager;
import android.os.Process;
import android.util.Log;

import com.newsblur.R;
import com.newsblur.activity.NbActivity;
import com.newsblur.database.BlurDatabaseHelper;
import static com.newsblur.database.BlurDatabaseHelper.closeQuietly;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Folder;
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
import com.newsblur.util.FeedSet;
import com.newsblur.util.FileCache;
import com.newsblur.util.NetworkUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadingAction;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StateFilter;
import com.newsblur.util.StoryOrder;

import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.TimeUnit;

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
public class NBSyncService extends Service {

    private static final Object WAKELOCK_MUTEX = new Object();
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

    public volatile static Boolean isPremium = null;
    public volatile static Boolean isStaff = null;

    private volatile static boolean isMemoryLow = false;
    private static long lastFeedCount = 0L;
    private static long lastFFConnMillis = 0L;
    private static long lastFFReadMillis = 0L;
    private static long lastFFParseMillis = 0L;
    private static long lastFFWriteMillis = 0L;

    /** Feed set that we need to sync immediately for the UI. */
    private static FeedSet PendingFeed;
    private static Integer PendingFeedTarget = 0;

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

    /** Flag to reset the reading session table. */
    public static boolean ResetSession = false;

    /** Actions that may need to be double-checked locally due to overlapping API calls. */
    private static List<ReadingAction> FollowupActions;
    static { FollowupActions = new ArrayList<ReadingAction>(); }

    /** Feed IDs (API stype) that have been acted upon and need a double-check for counts. */
    private static Set<FeedSet> RecountCandidates;
    static { RecountCandidates = new HashSet<FeedSet>(); }
    private volatile static boolean FlushRecounts = false;

    Set<String> orphanFeedIds;

    private ExecutorService primaryExecutor;
    CleanupService cleanupService;
    OriginalTextService originalTextService;
    UnreadsService unreadsService;
    ImagePrefetchService imagePrefetchService;

    PowerManager.WakeLock wl = null;
	APIManager apiManager;
    BlurDatabaseHelper dbHelper;
    private int lastStartIdCompleted = -1;

    /** The time of the last hard API failure we encountered. Used to implement back-off so that the sync
        service doesn't spin in the background chewing up battery when the API is unavailable. */
    private static long lastAPIFailure = 0;

    private static int lastActionCount = 0;

	@Override
	public void onCreate() {
		super.onCreate();
        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "onCreate");
        HaltNow = false;
        PowerManager pm = (PowerManager) getApplicationContext().getSystemService(POWER_SERVICE);
        wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, this.getClass().getSimpleName());
        wl.setReferenceCounted(true);

        primaryExecutor = Executors.newFixedThreadPool(1);
	}

    /**
     * Services can be constructed synchrnously by the Main thread, so don't do expensive
     * parts of construction in onCreate, but save them for when we are in our own thread.
     */
    private void finishConstruction() {
        if (apiManager == null) {
            apiManager = new APIManager(this);
            dbHelper = new BlurDatabaseHelper(this);
            cleanupService = new CleanupService(this);
            originalTextService = new OriginalTextService(this);
            unreadsService = new UnreadsService(this);
            imagePrefetchService = new ImagePrefetchService(this);
        }
    }

    /**
     * Called serially, once per "start" of the service.  This serves as a wakeup call
     * that the service should check for outstanding work.
     */
    @Override
    public int onStartCommand(Intent intent, int flags, final int startId) {
        // only perform a sync if the app is actually running or background syncs are enabled
        if (PrefsUtils.isOfflineEnabled(this) || (NbActivity.getActiveActivityCount() > 0)) {
            // Services actually get invoked on the main system thread, and are not
            // allowed to do tangible work.  We spawn a thread to do so.
            Runnable r = new Runnable() {
                public void run() {
                    doSync(startId);
                }
            };
            primaryExecutor.execute(r);
        } else {
            Log.d(this.getClass().getName(), "Skipping sync: app not active and background sync not enabled.");
            stopSelf(startId);
        } 

        // indicate to the system that the service should be alive when started, but
        // needn't necessarily persist under memory pressure
        return Service.START_NOT_STICKY;
    }

    /**
     * Do the actual work of syncing.
     */
    private synchronized void doSync(final int startId) {
        try {
            if (HaltNow) return;

            incrementRunningChild();
            finishConstruction();

            if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "starting primary sync");

            if (NbActivity.getActiveActivityCount() < 1) {
                // if the UI isn't running, politely run at background priority
                Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND);
            } else {
                // if the UI is running, run just one step below normal priority so we don't step on async tasks that are updating the UI
                Process.setThreadPriority(Process.THREAD_PRIORITY_DEFAULT + Process.THREAD_PRIORITY_LESS_FAVORABLE);
            }

            Thread.currentThread().setName(this.getClass().getName());

            if (OfflineNow) {
                OfflineNow = false;   
                NbActivity.updateAllActivities(NbActivity.UPDATE_STATUS);
            }

            // do this even if background syncs aren't enabled, because it absolutely must happen
            // on all devices
            housekeeping();

            // check to see if we are on an allowable network only after ensuring we have CPU
            if (!(PrefsUtils.isBackgroundNetworkAllowed(this) || (NbActivity.getActiveActivityCount() > 0))) {
                Log.d(this.getClass().getName(), "Abandoning sync: app not active and network type not appropriate for background sync.");
                return;
            }

            // ping activities to indicate that housekeeping is done, and the DB is safe to use
            NbActivity.updateAllActivities(NbActivity.UPDATE_DB_READY);

            originalTextService.start(startId);

            // first: catch up
            syncActions();
            
            // these requests are expressly enqueued by the UI/user, do them next
            syncPendingFeedStories();

            syncMetadata(startId);

            checkRecounts();

            unreadsService.start(startId);

            imagePrefetchService.start(startId);

            finishActions();

            if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "finishing primary sync");

        } catch (Exception e) {
            Log.e(this.getClass().getName(), "Sync error.", e);
        } finally {
            decrementRunningChild(startId);
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
                NbActivity.updateAllActivities(NbActivity.UPDATE_STATUS | NbActivity.UPDATE_REBUILD);
                // wipe the local DB if this is a first background run. if this is a first foreground
                // run, InitActivity will have wiped for us
                if (NbActivity.getActiveActivityCount() < 1) {
                    dbHelper.dropAndRecreateTables();
                }
                // in case this is the first time we have run since moving the cache to the new location,
                // blow away the old version entirely. This line can be removed some time well after
                // v61+ is widely deployed
                FileCache.cleanUpOldCache1(this);
                FileCache.cleanUpOldCache2(this);
                PrefsUtils.updateVersion(this);
            }

            boolean autoVac = PrefsUtils.isTimeToVacuum(this);
            // this will lock up the DB for a few seconds, only do it if the UI is hidden
            if (NbActivity.getActiveActivityCount() > 0) autoVac = false;
            
            if (upgraded || autoVac) {
                HousekeepingRunning = true;
                NbActivity.updateAllActivities(NbActivity.UPDATE_STATUS);
                Log.i(this.getClass().getName(), "rebuilding DB . . .");
                dbHelper.vacuum();
                Log.i(this.getClass().getName(), ". . . . done rebuilding DB");
                PrefsUtils.updateLastVacuumTime(this);
            }
        } finally {
            if (HousekeepingRunning) {
                HousekeepingRunning = false;
                NbActivity.updateAllActivities(NbActivity.UPDATE_METADATA);
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
            c = dbHelper.getActions(false);
            lastActionCount = c.getCount();
            if (lastActionCount < 1) return;

            ActionsRunning = true;

            actionsloop : while (c.moveToNext()) {
                NbActivity.updateAllActivities(NbActivity.UPDATE_STATUS);
                String id = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_ID));
                ReadingAction ra;
                try {
                    ra = ReadingAction.fromCursor(c);
                } catch (IllegalArgumentException e) {
                    Log.e(this.getClass().getName(), "error unfreezing ReadingAction", e);
                    dbHelper.clearAction(id);
                    continue actionsloop;
                }
                    
                if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "doing action: " + ra.toContentValues().toString());
                NewsBlurResponse response = ra.doRemote(apiManager);

                if (response == null) {
                    Log.e(this.getClass().getName(), "Discarding reading action with client-side error.");
                    dbHelper.clearAction(id);
                } else if (response.isProtocolError) {
                    // the network failed or we got a non-200, so be sure we retry
                    Log.i(this.getClass().getName(), "Holding reading action with server-side or network error.");
                    noteHardAPIFailure();
                    continue actionsloop;
                } else if (response.isError()) {
                    Log.e(this.getClass().getName(), "Discarding reading action with user error.");
                    dbHelper.clearAction(id);
                    String message = response.getErrorMessage(null);
                    if (message != null) NbActivity.toastError(message);
                } else {
                    // success!
                    dbHelper.clearAction(id);
                    FollowupActions.add(ra);
                }
                lastActionCount--;
            }
        } finally {
            closeQuietly(c);
            ActionsRunning = false;
            NbActivity.updateAllActivities(NbActivity.UPDATE_STATUS);
        }
    }

    /**
     * Some actions have a final, local step after being done remotely to ensure in-flight
     * API actions didn't race-overwrite them.  Do these, and then clean up the DB.
     */
    private void finishActions() {
        if (HaltNow) return;
        if (FollowupActions.size() < 1) return;

        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "double-checking " + FollowupActions.size() + " actions");
        int impactFlags = 0;
        for (ReadingAction ra : FollowupActions) {
            int impact = ra.doLocal(dbHelper);
            impactFlags |= impact;
        }
        NbActivity.updateAllActivities(impactFlags);

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
    private void syncMetadata(int startId) {
        if (DoFeedsFolders || PrefsUtils.isTimeToAutoSync(this)) {
            PrefsUtils.updateLastSyncTime(this);
            DoFeedsFolders = false;
        } else {
            return;
        }

        if (stopSync()) return;
        if (backoffBackgroundCalls()) return;
        if (dbHelper.getActions(false).getCount() > 0) return;

        FFSyncRunning = true;
        NbActivity.updateAllActivities(NbActivity.UPDATE_STATUS);

        // there is an issue with feeds that have no folder or folders that list feeds that do not exist.  capture them for workarounds.
        Set<String> debugFeedIdsFromFolders = new HashSet<String>();
        Set<String> debugFeedIdsFromFeeds = new HashSet<String>();
        orphanFeedIds = new HashSet<String>();

        try {
            FeedFolderResponse feedResponse = apiManager.getFolderFeedMapping(true);

            if (feedResponse == null) {
                noteHardAPIFailure();
                return;
            }

            // if the response says we aren't logged in, clear the DB and prompt for login. We test this
            // here, since this the first sync call we make on launch if we believe we are cookied.
            if (! feedResponse.isAuthenticated) {
                PrefsUtils.logout(this);
                return;
            }

            if (stopSync()) return;
            if (dbHelper.getActions(false).getCount() > 0) return;

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
                    // the feed is disabled/hidden, pretend it doesn't exist
                    continue feedaddloop;
                }
                feedValues.add(feed.getValues());
            }
            // also add the implied zero-id feed
            feedValues.add(Feed.getZeroFeed().getValues());

            // prune out missiong feed IDs from folders
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
            // the API vends the starred total as a different element, roll it into
            // the starred counts table using a special tag
            StarredCount totalStarred = new StarredCount();
            totalStarred.count = feedResponse.starredCount;
            totalStarred.tag = StarredCount.TOTAL_STARRED;
            starredCountValues.add(totalStarred.getValues());

            dbHelper.setFeedsFolders(folderValues, feedValues, socialFeedValues, starredCountValues);

            lastFFWriteMillis = System.currentTimeMillis() - startTime;
            lastFeedCount = feedValues.size();

            cleanupService.start(startId);
            unreadsService.start(startId);
            UnreadsService.doMetadata();

        } finally {
            FFSyncRunning = false;
            NbActivity.updateAllActivities(NbActivity.UPDATE_METADATA | NbActivity.UPDATE_STATUS);
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
            NbActivity.updateAllActivities(NbActivity.UPDATE_STATUS);

            // of all candidate feeds that were touched, now check to see if
            // any of them have mismatched local and remote counts we need to reconcile
            Set<FeedSet> dirtySets = new HashSet<FeedSet>();
            for (FeedSet fs : RecountCandidates) {
                if (dbHelper.getUnreadCount(fs, StateFilter.SOME) != dbHelper.getLocalUnreadCount(fs, StateFilter.SOME)) {
                    dirtySets.add(fs);
                }
            }
            if (dirtySets.size() < 1) {
                RecountCandidates.clear();
                return;
            }

            // if we are offline, the best we can do is perform a local unread recount and
            // save the true one for when we go back online.
            if (!NetworkUtils.isOnline(this)) {
                for (FeedSet fs : RecountCandidates) {
                    dbHelper.updateLocalFeedCounts(fs);
                }
            } else {
                if (stopSync()) return;
                Set<String> apiIds = new HashSet<String>();
                for (FeedSet fs : RecountCandidates) {
                    apiIds.addAll(fs.getFlatFeedIds());
                }

                // if any reading activities are pending, it makes no sense to recount yet
                if (dbHelper.getActions(false).getCount() > 0) return;

                UnreadCountResponse apiResponse = apiManager.getFeedUnreadCounts(apiIds);
                if ((apiResponse == null) || (apiResponse.isError())) {
                    Log.w(this.getClass().getName(), "Bad response to feed_unread_count");
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
                        dbHelper.updateSocialFeedCounts(feedId, entry.getValue().getValues());
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
                NbActivity.updateAllActivities(NbActivity.UPDATE_METADATA | NbActivity.UPDATE_STATUS);
            }
            FlushRecounts = false;
        }
    }

    /**
     * Fetch stories needed because the user is actively viewing a feed or folder.
     */
    private void syncPendingFeedStories() {
        // before anything else, see if we need to quickly reset fetch state for a feed
        if (ResetFeed != null) {
            ExhaustedFeeds.remove(ResetFeed);
            FeedStoriesSeen.remove(ResetFeed);
            FeedPagesSeen.remove(ResetFeed);
            ResetFeed = null;
        }

        FeedSet fs = PendingFeed;
        boolean finished = false;
        if (fs == null) {
            return;
        }
        try {
            if (ExhaustedFeeds.contains(fs)) {
                Log.i(this.getClass().getName(), "No more stories for feed set: " + fs);
                finished = true;
                return;
            }
            
            if (!FeedPagesSeen.containsKey(fs)) {
                FeedPagesSeen.put(fs, 0);
                FeedStoriesSeen.put(fs, 0);
                workaroundReadStoryTimestamp = (new Date()).getTime();
            }
            int pageNumber = FeedPagesSeen.get(fs);
            int totalStoriesSeen = FeedStoriesSeen.get(fs);

            StoryOrder order = PrefsUtils.getStoryOrder(this, fs);
            ReadFilter filter = PrefsUtils.getReadFilter(this, fs);

            synchronized (PENDING_FEED_MUTEX) {
                if (ResetSession) {
                    // the next fetch will be the start of a new reading session; clear it so it
                    // will be re-primed
                    dbHelper.clearStorySession();
                    // don't just rely on the auto-prepare code when fetching stories, it might be called
                    // after we insert our first page and not trigger
                    dbHelper.prepareReadingSession(fs);
                    ResetSession = false;
                }
            }
            
            while (totalStoriesSeen < PendingFeedTarget) {
                if (stopSync()) return;
                // this is a good heuristic for double-checking if we have left the story list
                if (FlushRecounts) return;
                // don't let the page loop block actions
                if (dbHelper.getActions(false).getCount() > 0) return;

                // bail if the active view has changed
                if (!fs.equals(PendingFeed)) {
                    return; 
                }

                StorySyncRunning = true;
                NbActivity.updateAllActivities(NbActivity.UPDATE_STATUS);

                pageNumber++;
                StoriesResponse apiResponse = apiManager.getStories(fs, pageNumber, order, filter);
            
                if (! isStoryResponseGood(apiResponse)) return;

                if (!fs.equals(PendingFeed)) {
                    return; 
                }

                insertStories(apiResponse, fs);
                // re-do any very recent actions that were incorrectly overwritten by this page
                finishActions();
                NbActivity.updateAllActivities(NbActivity.UPDATE_STORY);
            
                FeedPagesSeen.put(fs, pageNumber);
                totalStoriesSeen += apiResponse.stories.length;
                FeedStoriesSeen.put(fs, totalStoriesSeen);
                if (apiResponse.stories.length == 0) {
                    ExhaustedFeeds.add(fs);
                    finished = true;
                    return;
                }
            }
            finished = true;

        } finally {
            if (StorySyncRunning) {
                StorySyncRunning = false;
                NbActivity.updateAllActivities(NbActivity.UPDATE_STATUS);
            }
            synchronized (PENDING_FEED_MUTEX) {
                if (finished && fs.equals(PendingFeed)) PendingFeed = null;
            }
        }
    }

    private boolean isStoryResponseGood(StoriesResponse response) {
        if (response == null) {
            Log.e(this.getClass().getName(), "Null response received while loading stories.");
            return false;
        }
        if (response.stories == null) {
            Log.e(this.getClass().getName(), "Null stories member received while loading stories.");
            return false;
        }
        return true;
    }

    private long workaroundReadStoryTimestamp;

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

        dbHelper.insertStories(apiResponse, true);
    }

    void insertStories(StoriesResponse apiResponse) {
        dbHelper.insertStories(apiResponse, false);
    }

    void incrementRunningChild() {
        synchronized (WAKELOCK_MUTEX) {
            wl.acquire();
        }
    }

    void decrementRunningChild(int startId) {
        synchronized (WAKELOCK_MUTEX) {
            if (wl == null) return;
            if (wl.isHeld()) {
                wl.release();
            }
            // our wakelock reference counts.  only stop the service if it is in the background and if
            // we are the last thread to release the lock.
            if (!wl.isHeld()) {
                if (NbActivity.getActiveActivityCount() < 1) {
                    stopSelf(startId);
                }
                lastStartIdCompleted = startId;
                if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "wakelock depleted");
            }
        }
    }

    static boolean stopSync(Context context) {
        if (HaltNow) {
            if (AppConstants.VERBOSE_LOG) Log.d(NBSyncService.class.getName(), "stopping sync, soft interrupt set.");
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
        lastAPIFailure = System.currentTimeMillis();
    }

    private boolean backoffBackgroundCalls() {
        if (NbActivity.getActiveActivityCount() > 0) return false;
        if (System.currentTimeMillis() > (lastAPIFailure + AppConstants.API_BACKGROUND_BACKOFF_MILLIS)) return false;
        Log.i(this.getClass().getName(), "abandoning background sync due to recent API failures.");
        return true;
    }

    public void onTrimMemory (int level) {
        if (level > ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN) {
            isMemoryLow = true;
        }

        // this is also called when the UI is hidden, so double check if we need to
        // stop
        if ( (lastStartIdCompleted != -1) && (NbActivity.getActiveActivityCount() < 1)) {
            stopSelf(lastStartIdCompleted);
        }
    }

    /**
     * Is the main feed/folder list sync running?
     */
    public static boolean isFeedFolderSyncRunning() {
        return (HousekeepingRunning || ActionsRunning || RecountsRunning || FFSyncRunning || CleanupService.running() || UnreadsService.running() || StorySyncRunning || OriginalTextService.running() || ImagePrefetchService.running());
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
        if (CleanupService.running()) return context.getResources().getString(R.string.sync_status_cleanup);
        if (brief && !AppConstants.VERBOSE_LOG) return null;
        if (ActionsRunning) return String.format(context.getResources().getString(R.string.sync_status_actions), lastActionCount);
        if (RecountsRunning) return context.getResources().getString(R.string.sync_status_recounts);
        if (UnreadsService.running()) return String.format(context.getResources().getString(R.string.sync_status_unreads), UnreadsService.getPendingCount());
        if (OriginalTextService.running()) return String.format(context.getResources().getString(R.string.sync_status_text), OriginalTextService.getPendingCount());
        if (ImagePrefetchService.running()) return String.format(context.getResources().getString(R.string.sync_status_images), ImagePrefetchService.getPendingCount());
        if (!AppConstants.VERBOSE_LOG) return null;
        if (StorySyncRunning) return context.getResources().getString(R.string.sync_status_stories);
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
     * @param totalSeen the number of stories the caller thinks they have seen for the FeedSet
     *        or a negative number if the caller trusts us to track for them
     */
    public static boolean requestMoreForFeed(FeedSet fs, int desiredStoryCount, int callerSeen) {
        if (ExhaustedFeeds.contains(fs)) {
            if (AppConstants.VERBOSE_LOG) Log.i(NBSyncService.class.getName(), "rejecting request for feedset that is exhaused");
            return false;
        }

        synchronized (PENDING_FEED_MUTEX) {
            Integer alreadyPending = 0;
            if (fs.equals(PendingFeed)) alreadyPending = PendingFeedTarget;
            Integer alreadySeen = FeedStoriesSeen.get(fs);
            if (alreadySeen == null) alreadySeen = 0;
            if (callerSeen < alreadySeen) {
                // the caller is probably filtering and thinks they have fewer than we do, so
                // update our count to agree with them, and force-allow another requet
                alreadySeen = callerSeen;
                FeedStoriesSeen.put(fs, callerSeen);
                alreadyPending = 0;
            }

            if (AppConstants.VERBOSE_LOG) Log.d(NBSyncService.class.getName(), "callerhas: " + callerSeen + "  have:" + alreadySeen + "  want:" + desiredStoryCount + "  pending:" + alreadyPending);
            if (desiredStoryCount <= alreadySeen) {
                return false;
            }
            if (desiredStoryCount <= alreadyPending) {
                return false;
            }
            
            PendingFeed = fs;
            PendingFeedTarget = desiredStoryCount;
        }
        return true;
    }

    /**
     * Gracefully stop the loading of the current FeedSet, and set a flag so that the reading
     * session gets cleared before the next one is populated.
     */
    public static void resetReadingSession() {
        synchronized (PENDING_FEED_MUTEX) {
            PendingFeed = null;
            ResetSession = true;
        }
    }

    /**
     * Reset the API pagniation state for the given feedset, presumably because the order or filter changed.
     */
    public static void resetFetchState(FeedSet fs) {
        Log.d(NBSyncService.class.getName(), "requesting feed fetch state reset");
        ResetFeed = fs;
    }

    public static void getOriginalText(String hash) {
        OriginalTextService.addHash(hash);
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
        if (AppConstants.VERBOSE_LOG) Log.d(NBSyncService.class.getName(), "soft stop");
        HaltNow = true;
    }

    /**
     * Resets any internal temp vars or queues. Called when switching accounts.
     */
    public static void clearState() {
        resetReadingSession();
        FollowupActions.clear();
        RecountCandidates.clear();
        ExhaustedFeeds.clear();
        FeedPagesSeen.clear();
        FeedStoriesSeen.clear();
        OriginalTextService.clear();
        UnreadsService.clear();
        ImagePrefetchService.clear();
    }

    public static void resumeFromInterrupt() {
        HaltNow = false;
    }

    @Override
    public void onDestroy() {
        try {
            if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "onDestroy - stopping execution");
            HaltNow = true;
            if (cleanupService != null) cleanupService.shutdown();
            if (unreadsService != null) unreadsService.shutdown();
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
            if (dbHelper != null) dbHelper.close();
            if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "onDestroy - execution halted");
            super.onDestroy();
        } catch (Exception ex) {
            Log.e(this.getClass().getName(), "unclean shutdown", ex);
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    public static boolean isMemoryLow() {
        return isMemoryLow;
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

}
