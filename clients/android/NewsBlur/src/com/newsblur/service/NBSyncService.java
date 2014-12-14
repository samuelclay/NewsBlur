package com.newsblur.service;

import android.app.Service;
import android.content.ComponentCallbacks2;
import android.content.ContentValues;
import android.content.Intent;
import android.database.Cursor;
import android.os.IBinder;
import android.os.PowerManager;
import android.os.Process;
import android.text.TextUtils;
import android.util.Log;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.activity.NbActivity;
import com.newsblur.database.BlurDatabaseHelper;
import static com.newsblur.database.BlurDatabaseHelper.closeQuietly;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.domain.SocialFeed;
import com.newsblur.domain.Story;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.FeedFolderResponse;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.network.domain.StoryTextResponse;
import com.newsblur.network.domain.UnreadStoryHashesResponse;
import com.newsblur.util.AppConstants;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.ImageCache;
import com.newsblur.util.NetworkUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadingAction;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;

import java.util.ArrayList;
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

    /**
     * Mode switch for which newly received stories are suitable for display so
     * that they don't disrupt actively visible pager and list offsets.
     */
    public enum ActivationMode { ALL, OLDER, NEWER };

    // this value is somewhat arbitrary. ideally we would wait the max network timeout, but
    // the system like to force-kill terminating services that take too long, so it is often
    // moot to tune.
    private final static long SHUTDOWN_SLACK_SECONDS = 60L;

    private volatile static boolean ActionsRunning = false;
    private volatile static boolean CleanupRunning = false;
    private volatile static boolean FFSyncRunning = false;
    private volatile static boolean UnreadSyncRunning = false;
    private volatile static boolean UnreadHashSyncRunning = false;
    private volatile static boolean StorySyncRunning = false;
    private volatile static boolean OriginalTextSyncRunning = false;
    private volatile static boolean ImagePrefetchRunning = false;

    private volatile static boolean DoFeedsFolders = false;
    private volatile static boolean DoUnreads = false;
    private volatile static boolean HaltNow = false;
    private volatile static ActivationMode ActMode = ActivationMode.ALL;
    private volatile static long ModeCutoff = 0L;

    public volatile static Boolean isPremium = null;

    private volatile static boolean isMemoryLow = false;
    private static long lastFeedCount = 0L;
    private static long lastFFWriteMillis = 0L;

    /** Feed sets that we need to sync and how many stories the UI wants for them. */
    private static Map<FeedSet,Integer> PendingFeeds;
    static { PendingFeeds = new HashMap<FeedSet,Integer>(); }
    /** Feed sets that the API has said to have no more pages left. */
    private static Set<FeedSet> ExhaustedFeeds;
    static { ExhaustedFeeds = new HashSet<FeedSet>(); }
    /** The number of pages we have collected for the given feed set. */
    private static Map<FeedSet,Integer> FeedPagesSeen;
    static { FeedPagesSeen = new HashMap<FeedSet,Integer>(); }
    /** The number of stories we have collected for the given feed set. */
    private static Map<FeedSet,Integer> FeedStoriesSeen;
    static { FeedStoriesSeen = new HashMap<FeedSet,Integer>(); }

    /** Unread story hashes the API listed that we do not appear to have locally yet. */
    private static Set<String> StoryHashQueue;
    static { StoryHashQueue = new HashSet<String>(); }

    /** URLs of images contained in recently fetched stories that are candidates for prefetch. */
    private static Set<String> ImageQueue;
    static { ImageQueue = new HashSet<String>(); }

    /** Stories for which we want to fetch original text data. */
    private static Set<String> OriginalTextQueue;
    static { OriginalTextQueue = new HashSet<String>(); }

    /** Actions that may need to be double-checked locally due to overlapping API calls. */
    private static List<ReadingAction> FollowupActions;
    static { FollowupActions = new ArrayList<ReadingAction>(); }

    private Set<String> orphanFeedIds;

    private PowerManager.WakeLock wl = null;
    private ExecutorService primaryExecutor;
    private ExecutorService secondaryExecutor;
	private APIManager apiManager;
    private BlurDatabaseHelper dbHelper;
    private ImageCache imageCache;
    private int lastStartIdCompleted = -1;

	@Override
	public void onCreate() {
		super.onCreate();
        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "onCreate");
        HaltNow = false;
        PowerManager pm = (PowerManager) getApplicationContext().getSystemService(POWER_SERVICE);
        wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, this.getClass().getSimpleName());
        wl.setReferenceCounted(true);
        primaryExecutor = Executors.newFixedThreadPool(1);
        secondaryExecutor = Executors.newFixedThreadPool(1);
		apiManager = new APIManager(this);
        PrefsUtils.checkForUpgrade(this);
        dbHelper = new BlurDatabaseHelper(this);
        imageCache = new ImageCache(this);
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

            wl.acquire();
            if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "starting primary sync");

            // check to see if we are on an allowable network only after ensuring we have CPU
            if (!(PrefsUtils.isBackgroundNetworkAllowed(this) || (NbActivity.getActiveActivityCount() > 0))) {
                Log.d(this.getClass().getName(), "Abandoning sync: app not active and network type not appropriate for background sync.");
                return;
            }

            if (NbActivity.getActiveActivityCount() < 1) {
                // if the UI isn't running, politely run at background priority
                Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND);
            } else {
                // if the UI is running, run just one step below normal priority so we don't step on async tasks that are updating the UI
                Process.setThreadPriority(Process.THREAD_PRIORITY_DEFAULT + Process.THREAD_PRIORITY_LESS_FAVORABLE);
            }

            // first: catch up
            syncActions();
            
            // these requests are expressly enqueued by the UI/user, do them next
            syncPendingFeeds();

            syncMetadata();

            finishActions();
            if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "finishing primary sync");

            Runnable r = new Runnable() {
                public void run() {
                    doSyncSecondary(startId);
                }
            };
            secondaryExecutor.execute(r);

        } catch (Exception e) {
            Log.e(this.getClass().getName(), "Sync error.", e);
        }
    }

    /**
     * Do lower-priority sync tasks that are strictly safe to perform in parallel with
     * other tasks.
     */
    private synchronized void doSyncSecondary(int startId) {
        try {
            if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "starting secondary sync");
            // run one step below normal background priority
            Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND + Process.THREAD_PRIORITY_LESS_FAVORABLE);

            syncUnreads();

            syncOriginalTexts();
            
            prefetchImages();
            if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "finishing secondary sync");

        } catch (Exception e) {
            Log.e(this.getClass().getName(), "Sync error.", e);
        } finally {
            if (NbActivity.getActiveActivityCount() < 1) {
                stopSelf(startId);
            }
            lastStartIdCompleted = startId;
            if (wl != null) wl.release();
        }
    }

    /**
     * Perform any reading actions the user has done before we do anything else.
     */
    private void syncActions() {
        if (stopSync()) return;

        Cursor c = null;
        try {
            c = dbHelper.getActions(false);
            if (c.getCount() < 1) return;

            ActionsRunning = true;
            NbActivity.updateAllActivities();

            actionsloop : while (c.moveToNext()) {
                String id = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_ID));
                ReadingAction ra;
                try {
                    ra = ReadingAction.fromCursor(c);
                } catch (IllegalArgumentException e) {
                    Log.e(this.getClass().getName(), "error unfreezing ReadingAction", e);
                    dbHelper.clearAction(id);
                    continue actionsloop;
                }
                    
                NewsBlurResponse response = ra.doRemote(apiManager);

                // if we attempted a call and it failed, do not mark the action as done
                if (response != null) {
                    if (response.isError()) {
                        continue actionsloop;
                    }
                }

                dbHelper.clearAction(id);
                FollowupActions.add(ra);
            }
        } finally {
            closeQuietly(c);
            if (ActionsRunning) {
                ActionsRunning = false;
                NbActivity.updateAllActivities();
            }
        }
    }

    /**
     * Some actions have a final, local step after being done remotely to ensure in-flight
     * API actions didn't race-overwrite them.  Do these, and then clean up the DB.
     */
    private void finishActions() {
        if (HaltNow) return;
        if (FollowupActions.size() < 1) return;

        for (ReadingAction ra : FollowupActions) {
            ra.doLocal(dbHelper);
        }
        FollowupActions.clear();
    }

    /**
     * The very first step of a sync - get the feed/folder list, unread counts, and
     * unread hashes. Doing this resets pagination on the server!
     */
    private void syncMetadata() {
        if (stopSync()) return;
        if (ActMode != ActivationMode.ALL) return;

        if (DoFeedsFolders || PrefsUtils.isTimeToAutoSync(this)) {
            PrefsUtils.updateLastSyncTime(this);
            DoFeedsFolders = false;
        } else {
            return;
        }

        // cleanup is expensive, so do it as part of the metadata sync
        CleanupRunning = true;
        NbActivity.updateAllActivities();
        dbHelper.cleanupStories(PrefsUtils.isKeepOldStories(this));
        imageCache.cleanup();
        dbHelper.cleanupStoryText();
        CleanupRunning = false;
        NbActivity.updateAllActivities();

        // cleanup may have taken a while, so re-check our running status
        if (stopSync()) return;
        if (ActMode != ActivationMode.ALL) return;

        FFSyncRunning = true;
        NbActivity.updateAllActivities();

        // there is a rare issue with feeds that have no folder.  capture them for workarounds.
        Set<String> debugFeedIds = new HashSet<String>();
        orphanFeedIds = new HashSet<String>();

        try {
            // a metadata sync invalidates pagination and feed status
            ExhaustedFeeds.clear();
            FeedPagesSeen.clear();
            FeedStoriesSeen.clear();
            StoryHashQueue.clear();

            FeedFolderResponse feedResponse = apiManager.getFolderFeedMapping(true);

            if (feedResponse == null) {
                return;
            }

            // if the response says we aren't logged in, clear the DB and prompt for login. We test this
            // here, since this the first sync call we make on launch if we believe we are cookied.
            if (! feedResponse.isAuthenticated) {
                PrefsUtils.logout(this);
                return;
            }

            long startTime = System.currentTimeMillis();

            isPremium = feedResponse.isPremium;

            // clean out the feed / folder tables
            dbHelper.cleanupFeedsFolders();

            // data for the folder and folder-feed-mapping tables
            List<ContentValues> folderValues = new ArrayList<ContentValues>();
            List<ContentValues> ffmValues = new ArrayList<ContentValues>();
            for (Entry<String, List<Long>> entry : feedResponse.folders.entrySet()) {
                if (!TextUtils.isEmpty(entry.getKey())) {
                    String folderName = entry.getKey().trim();
                    if (!TextUtils.isEmpty(folderName)) {
                        ContentValues values = new ContentValues();
                        values.put(DatabaseConstants.FOLDER_NAME, folderName);
                        folderValues.add(values);
                    }

                    for (Long feedId : entry.getValue()) {
                        ContentValues values = new ContentValues(); 
                        values.put(DatabaseConstants.FEED_FOLDER_FEED_ID, feedId);
                        values.put(DatabaseConstants.FEED_FOLDER_FOLDER_NAME, folderName);
                        ffmValues.add(values);
                        // note all feeds that belong to some folder
                        debugFeedIds.add(Long.toString(feedId));
                    }
                }
            }

            // data for the feeds table
            List<ContentValues> feedValues = new ArrayList<ContentValues>();
            feedaddloop: for (String feedId : feedResponse.feeds.keySet()) {
                // sanity-check that the returned feeds actually exist in a folder or at the root
                // if they do not, they should neither display nor count towards unread numbers
                if (! debugFeedIds.contains(feedId)) {
                    Log.w(this.getClass().getName(), "Found and ignoring un-foldered feed: " + feedId );
                    orphanFeedIds.add(feedId);
                    continue feedaddloop;
                }
                if (! feedResponse.feeds.get(feedId).active) {
                    // the feed is disabled/hidden, pretend it doesn't exist
                    continue feedaddloop;
                }
                feedValues.add(feedResponse.feeds.get(feedId).getValues());
            }
            
            // data for the the social feeds table
            List<ContentValues> socialFeedValues = new ArrayList<ContentValues>();
            for (SocialFeed feed : feedResponse.socialFeeds) {
                socialFeedValues.add(feed.getValues());
            }
            
            dbHelper.insertFeedsFolders(feedValues, folderValues, ffmValues, socialFeedValues);

            // populate the starred stories count table
            dbHelper.updateStarredStoriesCount(feedResponse.starredCount);

            lastFFWriteMillis = System.currentTimeMillis() - startTime;
            lastFeedCount = feedValues.size();

            DoUnreads = true;

        } finally {
            FFSyncRunning = false;
            NbActivity.updateAllActivities();
        }

    }

    /**
     * Fetch any unread stories (by hash) that we learnt about during the FFSync.
     */
    private void syncUnreads() {
        if (HaltNow) return;

        try {
            // only use the unread status API if the user is premium
            if ((isPremium == Boolean.TRUE) && DoUnreads) {
                UnreadHashSyncRunning = true;
                NbActivity.updateAllActivities();
                UnreadStoryHashesResponse unreadHashes = apiManager.getUnreadStoryHashes();
                
                // note all the stories we thought were unread before. if any fail to appear in
                // the API request for unreads, we will mark them as read
                List<String> oldUnreadHashes = dbHelper.getUnreadStoryHashes();

                for (Entry<String, String[]> entry : unreadHashes.unreadHashes.entrySet()) {
                    String feedId = entry.getKey();
                    // ignore unreads from orphaned feeds
                    if( ! orphanFeedIds.contains(feedId)) {
                        // only fetch the reported unreads if we don't already have them
                        List<String> existingHashes = dbHelper.getStoryHashesForFeed(feedId);
                        for (String newHash : entry.getValue()) {
                            if (!existingHashes.contains(newHash)) {
                                StoryHashQueue.add(newHash);
                            }
                            oldUnreadHashes.remove(newHash);
                        }
                    }
                }

                dbHelper.markStoryHashesRead(oldUnreadHashes);

                DoUnreads = false;
            } 
        } finally {
            UnreadHashSyncRunning = false;
            NbActivity.updateAllActivities();
        }

        try {
            unreadsyncloop: while (StoryHashQueue.size() > 0) {
                if (stopSync()) return;

                UnreadSyncRunning = true;
                NbActivity.updateAllActivities();

                List<String> hashBatch = new ArrayList(AppConstants.UNREAD_FETCH_BATCH_SIZE);
                batchloop: for (String hash : StoryHashQueue) {
                    hashBatch.add(hash);
                    if (hashBatch.size() >= AppConstants.UNREAD_FETCH_BATCH_SIZE) break batchloop;
                }
                StoriesResponse response = apiManager.getStoriesByHash(hashBatch);
                if (! isStoryResponseGood(response)) {
                    Log.e(this.getClass().getName(), "error fetching unreads batch, abandoning sync.");
                    break unreadsyncloop;
                }
                dbHelper.insertStories(response);
                dbHelper.markStoriesActive(ActMode, ModeCutoff);
                for (String hash : hashBatch) {
                    StoryHashQueue.remove(hash);
                } 

                for (Story story : response.stories) {
                    if (story.imageUrls != null) {
                        for (String url : story.imageUrls) {
                            ImageQueue.add(url);
                        }
                    }
                    DefaultFeedView mode = PrefsUtils.getDefaultFeedViewForFeed(this, story.feedId);
                    if (mode == DefaultFeedView.TEXT) {
                        OriginalTextQueue.add(story.storyHash);
                    }
                }
            }
        } finally {
            if (UnreadSyncRunning) {
                UnreadSyncRunning = false;
                NbActivity.updateAllActivities();
            }
        }
    }

    private void syncOriginalTexts() {
        try {
            while (OriginalTextQueue.size() > 0) {
                OriginalTextSyncRunning = true;
                NbActivity.updateAllActivities();

                Set<String> fetchedHashes = new HashSet<String>();
                Set<String> batch = new HashSet<String>(AppConstants.IMAGE_PREFETCH_BATCH_SIZE);
                batchloop: for (String hash : OriginalTextQueue) {
                    batch.add(hash);
                    if (batch.size() >= AppConstants.IMAGE_PREFETCH_BATCH_SIZE) break batchloop;
                }
                try {
                    fetchloop: for (String hash : batch) {
                        if (stopSync()) return;
                        
                        String result = "";
                        StoryTextResponse response = apiManager.getStoryText(FeedUtils.inferFeedId(hash), hash);
                        if ((response != null) && (response.originalText != null)) {
                            result = response.originalText;
                        }
                        dbHelper.putStoryText(hash, result);

                        fetchedHashes.add(hash);
                    }
                } finally {
                    OriginalTextQueue.removeAll(fetchedHashes);
                }
            }
        } finally {
            if (OriginalTextSyncRunning) {
                OriginalTextSyncRunning = false;
                NbActivity.updateAllActivities();
            }
        }
    }

    /**
     * Fetch stories needed because the user is actively viewing a feed or folder.
     */
    private void syncPendingFeeds() {
        try {
            Set<FeedSet> handledFeeds = new HashSet<FeedSet>();
            feedloop: for (FeedSet fs : PendingFeeds.keySet()) {

                if (ExhaustedFeeds.contains(fs)) {
                    Log.i(this.getClass().getName(), "No more stories for feed set: " + fs);
                    handledFeeds.add(fs);
                    continue feedloop;
                }

                StorySyncRunning = true;
                NbActivity.updateAllActivities();
                
                if (!FeedPagesSeen.containsKey(fs)) {
                    FeedPagesSeen.put(fs, 0);
                    FeedStoriesSeen.put(fs, 0);
                }
                int pageNumber = FeedPagesSeen.get(fs);
                int totalStoriesSeen = FeedStoriesSeen.get(fs);

                StoryOrder order = PrefsUtils.getStoryOrder(this, fs);
                ReadFilter filter = PrefsUtils.getReadFilter(this, fs);
                
                pageloop: while (totalStoriesSeen < PendingFeeds.get(fs)) {
                    if (stopSync()) return;

                    pageNumber++;
                    StoriesResponse apiResponse = apiManager.getStories(fs, pageNumber, order, filter);
                
                    if (! isStoryResponseGood(apiResponse)) break feedloop;

                    FeedPagesSeen.put(fs, pageNumber);
                    totalStoriesSeen += apiResponse.stories.length;
                    FeedStoriesSeen.put(fs, totalStoriesSeen);

                    dbHelper.insertStories(apiResponse);
                    dbHelper.markStoriesActive(ActMode, ModeCutoff);
                
                    if (apiResponse.stories.length == 0) {
                        ExhaustedFeeds.add(fs);
                        break pageloop;
                    }
                }

                handledFeeds.add(fs);
            }

            PendingFeeds.keySet().removeAll(handledFeeds);
        } finally {
            if (StorySyncRunning) {
                StorySyncRunning = false;
                NbActivity.updateAllActivities();
            }
        }
    }

    private void prefetchImages() {
        try {
            while (ImageQueue.size() > 0) {
                if (!PrefsUtils.isImagePrefetchEnabled(this)) return;
                ImagePrefetchRunning = true;
                NbActivity.updateAllActivities();

                Set<String> fetchedImages = new HashSet<String>();
                Set<String> batch = new HashSet<String>(AppConstants.IMAGE_PREFETCH_BATCH_SIZE);
                batchloop: for (String url : ImageQueue) {
                    batch.add(url);
                    if (batch.size() >= AppConstants.IMAGE_PREFETCH_BATCH_SIZE) break batchloop;
                }
                try {
                    for (String url : batch) {
                        if (stopSync()) return;
                        
                        imageCache.cacheImage(url);

                        fetchedImages.add(url);
                    }
                } finally {
                    ImageQueue.removeAll(fetchedImages);
                }
            }
        } finally {
            if (ImagePrefetchRunning) {
                ImagePrefetchRunning = false;
                NbActivity.updateAllActivities();
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

    private boolean stopSync() {
        if (HaltNow) {
            if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "stopping sync, soft interrupt set.");
            return true;
        }
        if (!NetworkUtils.isOnline(this)) return true;
        return false;
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
        return (ActionsRunning || FFSyncRunning || CleanupRunning || UnreadSyncRunning || StorySyncRunning || OriginalTextSyncRunning || ImagePrefetchRunning);
    }

    /**
     * Is there a sync for a given FeedSet running?
     */
    public static boolean isFeedSetSyncing(FeedSet fs) {
        return (PendingFeeds.containsKey(fs) && StorySyncRunning);
    }

    public static String getSyncStatusMessage() {
        if (ActionsRunning) return "Catching up reading actions . . .";
        if (FFSyncRunning) return "Syncing feeds . . .";
        if (CleanupRunning) return "Cleaning up storage . . .";
        if (StorySyncRunning) return "Syncing stories . . .";
        if (UnreadHashSyncRunning) return "Syncing unread status . . .";
        if (UnreadSyncRunning) return "Syncing " + StoryHashQueue.size() + " stories . . .";
        if (ImagePrefetchRunning) return "Caching " + ImageQueue.size() + " images . . .";
        if (OriginalTextSyncRunning) return "Syncing text for " + OriginalTextQueue.size() + " stories. . .";
        return null;
    }

    /**
     * Force a refresh of feed/folder data on the next sync, even if enough time
     * hasn't passed for an autosync.
     */
    public static void forceFeedsFolders() {
        DoFeedsFolders = true;
    }

    /**
     * Tell the service which stories can be activated if received. See ActivationMode.
     */
    public static void setActivationMode(ActivationMode actMode) {
        ActMode = actMode;
    }

    public static void setActivationMode(ActivationMode actMode, long modeCutoff) {
        ActMode = actMode;
        ModeCutoff = modeCutoff;
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

        synchronized (PendingFeeds) {
            Integer alreadySeen = FeedStoriesSeen.get(fs);
            Integer alreadyRequested = PendingFeeds.get(fs);
            if (alreadySeen == null) alreadySeen = 0;
            if (alreadyRequested == null) alreadyRequested = 0;
            if ((callerSeen >= 0) && (alreadySeen > callerSeen)) {
                // the caller is probably filtering and thinks they have fewer than we do, so
                // update our count to agree with them, and force-allow another requet
                alreadySeen = callerSeen;
                FeedStoriesSeen.put(fs, callerSeen);
                alreadyRequested = 0;
            }
            if (AppConstants.VERBOSE_LOG) Log.d(NBSyncService.class.getName(), "have:" + alreadySeen + "  want:" + desiredStoryCount + " requested:" + alreadyRequested);
            if (desiredStoryCount <= alreadySeen) {
                return false;
            }
            if (desiredStoryCount <= alreadyRequested) {
                return false;
            }
        }
            
        PendingFeeds.put(fs, desiredStoryCount);
        return true;
    }

    public static void resetFeeds() {
        ExhaustedFeeds.clear();
        FeedPagesSeen.clear();
        FeedStoriesSeen.clear();
    }

    public static void getOriginalText(String hash) {
        OriginalTextQueue.add(hash);
    }

    public static void softInterrupt() {
        if (AppConstants.VERBOSE_LOG) Log.d(NBSyncService.class.getName(), "soft stop");
        HaltNow = true;
    }

    public static void resumeFromInterrupt() {
        HaltNow = false;
    }

    @Override
    public void onDestroy() {
        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "onDestroy - stopping execution");
        HaltNow = true;
        primaryExecutor.shutdown();
        secondaryExecutor.shutdown();
        try {
            primaryExecutor.awaitTermination(SHUTDOWN_SLACK_SECONDS, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            primaryExecutor.shutdownNow();
            Thread.currentThread().interrupt();
        }
        try {
            secondaryExecutor.awaitTermination(SHUTDOWN_SLACK_SECONDS, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            secondaryExecutor.shutdownNow();
            Thread.currentThread().interrupt();
        }
        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "onDestroy - execution halted");

        super.onDestroy();
        dbHelper.close();
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
        s.append(lastFeedCount).append(" in ").append(lastFFWriteMillis);
        return s.toString();
    }

}
