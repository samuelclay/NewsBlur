package com.newsblur.service;

import android.app.Service;
import android.content.ComponentCallbacks2;
import android.content.ContentValues;
import android.content.Intent;
import android.database.Cursor;
import android.os.IBinder;
import android.os.PowerManager;
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
import com.newsblur.network.domain.UnreadStoryHashesResponse;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedSet;
import com.newsblur.util.ImageCache;
import com.newsblur.util.PrefsUtils;
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

    private volatile static boolean ActionsRunning = false;
    private volatile static boolean CleanupRunning = false;
    private volatile static boolean FFSyncRunning = false;
    private volatile static boolean UnreadSyncRunning = false;
    private volatile static boolean UnreadHashSyncRunning = false;
    private volatile static boolean StorySyncRunning = false;
    private volatile static boolean ImagePrefetchRunning = false;

    /** Don't do any actions that might modify the story list for a feed or folder in a way that
        would annoy a user who is on the story list or paging through stories. */
    private volatile static boolean HoldStories = false;
    private volatile static boolean DoFeedsFolders = false;
    private volatile static boolean isMemoryLow = false;
    private volatile static boolean HaltNow = false;

    /** Feed sets that we need to sync and how many stories the UI wants for them. */
    private static Map<FeedSet,Integer> PendingFeeds;
    static { PendingFeeds = new HashMap<FeedSet,Integer>(); }
    private static Set<FeedSet> ExhaustedFeeds;
    static { ExhaustedFeeds = new HashSet<FeedSet>(); }
    private static Map<FeedSet,Integer> FeedPagesSeen;
    static { FeedPagesSeen = new HashMap<FeedSet,Integer>(); }
    private static Map<FeedSet,Integer> FeedStoriesSeen;
    static { FeedStoriesSeen = new HashMap<FeedSet,Integer>(); }
    private static Set<String> StoryHashQueue;
    static { StoryHashQueue = new HashSet<String>(); }
    private static Set<String> ImageQueue;
    static { ImageQueue = new HashSet<String>(); }

    private PowerManager.WakeLock wl = null;
    private ExecutorService executor;
	private APIManager apiManager;
    private BlurDatabaseHelper dbHelper;
    private ImageCache imageCache;
    private int lastStartIdCompleted = -1;

	@Override
	public void onCreate() {
		super.onCreate();
        Log.d(this.getClass().getName(), "onCreate");
        HaltNow = false;
        PowerManager pm = (PowerManager) getApplicationContext().getSystemService(POWER_SERVICE);
        wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, this.getClass().getSimpleName());
        wl.setReferenceCounted(false);
        executor = Executors.newFixedThreadPool(1);
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
            executor.execute(r);
        } else {
            Log.d(this.getClass().getName(), "Skipping sync: app not active and background sync not enabled.");
        } 

        // indicate to the system that the service should be alive when started, but
        // needn't necessarily persist under memory pressure
        return Service.START_NOT_STICKY;
    }

    /**
     * Do the actual work of syncing.
     */
    private synchronized void doSync(int startId) {
        try {
            if (HaltNow) return;

            Log.d(this.getClass().getName(), "starting sync . . .");

            wl.acquire();

            // check to see if we are on an allowable network only after ensuring we have CPU
            if (!(PrefsUtils.isBackgroundNetworkAllowed(this) || (NbActivity.getActiveActivityCount() > 0))) {
                Log.d(this.getClass().getName(), "Abandoning sync: app not active and network type not appropriate for background sync.");
                return;
            }

            // first: catch up
            syncActions();
            
            // these requests are expressly enqueued by the UI/user, do them next
            syncPendingFeeds();

            syncMetadata();

            syncUnreads();

            finishActions();
            
            prefetchImages();

        } catch (Exception e) {
            Log.e(this.getClass().getName(), "Sync error.", e);
        } finally {
            lastStartIdCompleted = startId;
            if (wl != null) wl.release();
            Log.d(this.getClass().getName(), " . . . sync done");
        }

        if (isMemoryLow && (NbActivity.getActiveActivityCount() < 1)) {
            stopSelf(startId);
        }
    }

    /**
     * Perform any reading actions the user has done before we do anything else.
     */
    private void syncActions() {
        // TODO: replace all halting checks with full check for connectivity or interrupts
        if (HaltNow) return;

        Cursor c = null;
        try {
            c = dbHelper.getActions(false);
            if (c.getCount() < 1) return;

            Log.d(this.getClass().getName(), "found new actions: " + c.getCount());
            ActionsRunning = true;
            NbActivity.updateAllActivities();

            actionsloop : while (c.moveToNext()) {
                String id = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_ID));
                NewsBlurResponse response = null;
                if (c.getInt(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_MARK_READ)) == 1) {
                    String hash = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_HASH));
                    String feedIds = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_FEED_ID));
                    Long includeOlder = DatabaseConstants.nullIfZero(c.getLong(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_INCLUDE_OLDER)));
                    Long includeNewer = DatabaseConstants.nullIfZero(c.getLong(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_INCLUDE_NEWER)));
                    if (hash != null) {
                        response = apiManager.markStoryAsRead(hash);
                    } else if (feedIds != null) {
                        Set<String> feeds = new HashSet<String>();
                        for (String feedId : TextUtils.split(feedIds, ",")) feeds.add(feedId);
                        if (feeds.size() == 0) {
                            response = apiManager.markAllAsRead();
                        } else {
                            response = apiManager.markFeedsAsRead(feeds, includeOlder, includeNewer);
                        }
                    } else {
                        Log.w(this.getClass().getName(), "discarding mark-read action of unknown type: " + id);
                    }
                } else if (c.getInt(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_MARK_UNREAD)) == 1) {
                    String hash = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_HASH));
                    response = apiManager.markStoryHashUnread(hash);
                } else {
                    Log.w(this.getClass().getName(), "discarding action of unknown type: " + id);
                }

                // if we attempted a call and it failed, do not mark the action as done
                if (response != null) {
                    if (response.isError()) {
                        continue actionsloop;
                    }
                }

                dbHelper.setActionDone(id);
            }
        } finally {
            closeQuietly(c);
            ActionsRunning = false;
            NbActivity.updateAllActivities();
        }
    }

    /**
     * Some actions have a final, local step after being done remotely to ensure in-flight
     * API actions didn't race-overwrite them.  Do these, and then clean up the DB.
     */
    private void finishActions() {
        if (HaltNow) return;

        Cursor c = null;
        try {
            c = dbHelper.getActions(true);
            if (c.getCount() < 1) return;

            Log.d(this.getClass().getName(), "found done actions: " + c.getCount());
            ActionsRunning = true;
            NbActivity.updateAllActivities();

            while (c.moveToNext()) {
                String id = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_ID));
                if (c.getInt(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_MARK_READ)) == 1) {
                    String hash = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_HASH));
                    if (hash != null ) {
                        dbHelper.setStoryReadState(hash, true);
                    }
                    // TODO: double-check stories from feed-marks
                } else if (c.getInt(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_MARK_UNREAD)) == 1) {
                    String hash = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_HASH));
                    dbHelper.setStoryReadState(hash, false);
                } else {
                    Log.w(this.getClass().getName(), "discarding action of unknown type: " + id);
                }
                dbHelper.clearAction(id);
            }
        } finally {
            closeQuietly(c);
            ActionsRunning = false;
            NbActivity.updateAllActivities();
        }
    }

    /**
     * The very first step of a sync - get the feed/folder list, unread counts, and
     * unread hashes. Doing this resets pagination on the server!
     */
    private void syncMetadata() {
        if (HaltNow) return;
        if (HoldStories) return;

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
        CleanupRunning = false;
        NbActivity.updateAllActivities();

        if (HaltNow) return;
        if (HoldStories) return;

        FFSyncRunning = true;
        NbActivity.updateAllActivities();

        // there is a rare issue with feeds that have no folder.  capture them for workarounds.
        List<String> debugFeedIds = new ArrayList<String>();

        // remember if we are premium
        boolean isPremium;

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
            for (String feedId : feedResponse.feeds.keySet()) {
                // sanity-check that the returned feeds actually exist in a folder or at the root
                // if they do not, they should neither display nor count towards unread numbers
                if (debugFeedIds.contains(feedId)) {
                    feedValues.add(feedResponse.feeds.get(feedId).getValues());
                } else {
                    Log.w(this.getClass().getName(), "Found and ignoring un-foldered feed: " + feedId );
                }
            }
            
            // data for the the social feeds table
            List<ContentValues> socialFeedValues = new ArrayList<ContentValues>();
            for (SocialFeed feed : feedResponse.socialFeeds) {
                socialFeedValues.add(feed.getValues());
            }
            
            dbHelper.insertFeedsFolders(feedValues, folderValues, ffmValues, socialFeedValues);

            // populate the starred stories count table
            dbHelper.updateStarredStoriesCount(feedResponse.starredCount);

        } finally {
            FFSyncRunning = false;
            NbActivity.updateAllActivities();
        }

        if (HaltNow) return;
        if (HoldStories) return;

        UnreadHashSyncRunning = true;

        try {

            UnreadStoryHashesResponse unreadHashes = apiManager.getUnreadStoryHashes();
            
            // note all the stories we thought were unread before. if any fail to appear in
            // the API request for unreads, we will mark them as read
            List<String> oldUnreadHashes = dbHelper.getUnreadStoryHashes();

            for (Entry<String, String[]> entry : unreadHashes.unreadHashes.entrySet()) {
                String feedId = entry.getKey();
                // ignore unreads from orphaned feeds
                if( debugFeedIds.contains(feedId)) {
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

            // only trust the unread status of this API if the user is premium
            if (isPremium) {
                dbHelper.markStoryHashesRead(oldUnreadHashes);
            }
        } finally {
            UnreadHashSyncRunning = false;
            NbActivity.updateAllActivities();
        }
    }

    /**
     * Fetch any unread stories (by hash) that we learnt about during the FFSync.
     */
    private void syncUnreads() {
        UnreadSyncRunning = true;
        try {
            unreadsyncloop: while (StoryHashQueue.size() > 0) {
                if (HaltNow) return;
                if (HoldStories) return;

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
                for (String hash : hashBatch) {
                    StoryHashQueue.remove(hash);
                } 
                NbActivity.updateAllActivities();

                for (Story story : response.stories) {
                    if (story.imageUrls != null) {
                        for (String url : story.imageUrls) {
                            ImageQueue.add(url);
                        }
                    }
                }
            }
        } finally {
            UnreadSyncRunning = false;
            NbActivity.updateAllActivities();
        }
    }

    /**
     * Fetch stories needed because the user is actively viewing a feed or folder.
     */
    private void syncPendingFeeds() {
        StorySyncRunning = true;
            
        try {
            Set<FeedSet> handledFeeds = new HashSet<FeedSet>();
            feedloop: for (FeedSet fs : PendingFeeds.keySet()) {
                NbActivity.updateAllActivities();
                if (HaltNow) return;

                if (ExhaustedFeeds.contains(fs)) {
                    Log.i(this.getClass().getName(), "No more stories for feed set: " + fs);
                    handledFeeds.add(fs);
                    continue feedloop;
                }
                
                if (!FeedPagesSeen.containsKey(fs)) {
                    FeedPagesSeen.put(fs, 0);
                    FeedStoriesSeen.put(fs, 0);
                }
                int pageNumber = FeedPagesSeen.get(fs);
                int totalStoriesSeen = FeedStoriesSeen.get(fs);

                StoryOrder order = PrefsUtils.getStoryOrder(this, fs);
                ReadFilter filter = PrefsUtils.getReadFilter(this, fs);
                
                pageloop: while (totalStoriesSeen < PendingFeeds.get(fs)) {
                    if (HaltNow) return;

                    pageNumber++;
                    StoriesResponse apiResponse = apiManager.getStories(fs, pageNumber, order, filter);
                
                    if (! isStoryResponseGood(apiResponse)) break feedloop;

                    FeedPagesSeen.put(fs, pageNumber);
                    totalStoriesSeen += apiResponse.stories.length;
                    FeedStoriesSeen.put(fs, totalStoriesSeen);

                    dbHelper.insertStories(apiResponse);
                    NbActivity.updateAllActivities();
                
                    if (apiResponse.stories.length == 0) {
                        ExhaustedFeeds.add(fs);
                        break pageloop;
                    }
                }

                handledFeeds.add(fs);
            }

            PendingFeeds.keySet().removeAll(handledFeeds);
        } finally {
            StorySyncRunning = false;
        }
    }

    private void prefetchImages() {
        if (!PrefsUtils.isImagePrefetchEnabled(this)) return;
        ImagePrefetchRunning = true;
        try {
            while (ImageQueue.size() > 0) {
                Set<String> fetchedImages = new HashSet<String>();
                Set<String> batch = new HashSet<String>(AppConstants.IMAGE_PREFETCH_BATCH_SIZE);
                batchloop: for (String url : ImageQueue) {
                    batch.add(url);
                    if (batch.size() >= AppConstants.IMAGE_PREFETCH_BATCH_SIZE) break batchloop;
                }
                try {
                    for (String url : batch) {
                        if (HaltNow) return;
                        if (HoldStories) return;
                        
                        imageCache.cacheImage(url);

                        fetchedImages.add(url);
                    }
                } finally {
                    ImageQueue.removeAll(fetchedImages);
                    NbActivity.updateAllActivities();
                }
            }
        } finally {
            ImagePrefetchRunning = false;
            NbActivity.updateAllActivities();

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

    public void onTrimMemory (int level) {
        // be nice and stop if memory is even a tiny bit pressured and we aren't visible;
        // the OS penalises long-running processes, and it is reasonably cheap to re-create ourself.
        if (level > ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN) {
            isMemoryLow = true;

            // if the UI is still active, definitely don't stop
            if (NbActivity.getActiveActivityCount() > 0) return;
        
            if (lastStartIdCompleted != -1) {
                stopSelf(lastStartIdCompleted);
            }
        }
    }

    /**
     * Is the main feed/folder list sync running?
     */
    public static boolean isFeedFolderSyncRunning() {
        return (ActionsRunning || FFSyncRunning || CleanupRunning || UnreadSyncRunning || StorySyncRunning || ImagePrefetchRunning);
    }

    /**
     * Is there a sync for a given FeedSet running?
     */
    public static boolean isFeedSetSyncing(FeedSet fs) {
        return PendingFeeds.containsKey(fs);
    }

    public static String getSyncStatusMessage() {
        if (ActionsRunning) return "Catching up reading actions . . .";
        if (FFSyncRunning) return "Syncing feeds . . .";
        if (CleanupRunning) return "Cleaning up storage . . .";
        if (UnreadHashSyncRunning) return "Syncing unread status . . .";
        if (UnreadSyncRunning) return "Syncing " + StoryHashQueue.size() + " stories . . .";
        if (ImagePrefetchRunning) return "Caching " + ImageQueue.size() + " images . . .";
        if (StorySyncRunning) return "Syncing stories . . .";
        return null;
    }

    /**
     * Force a refresh of feed/folder data on the next sync, even if enough time
     * hasn't passed for an autosync.
     */
    public static void forceFeedsFolders() {
        DoFeedsFolders = true;
        NbActivity.updateAllActivities();
    }

    /**
     * Indicates that now is *not* an appropriate time to modify the story list because the user is
     * actively seeing stories. Only updates and appends should be performed, not cleanup or
     * a pagination reset.
     */
    public static void holdStories(boolean holdStories) {
        HoldStories = holdStories;
    }

    /**
     * Requests that the service fetch additional stories for the specified feed/folder. Returns
     * true if more will be fetched as a result of this request.
     *
     * @param desiredStoryCount the minimum number of stories to fetch.
     */
    public static boolean requestMoreForFeed(FeedSet fs, int desiredStoryCount) {
        if (ExhaustedFeeds.contains(fs)) {
            Log.e(NBSyncService.class.getName(), "rejecting request for feedset that is exhaused");
            return false;
        }
        Integer alreadyRequested = PendingFeeds.get(fs);
        if ((alreadyRequested != null) && (desiredStoryCount <= alreadyRequested)) {
            return false;
        }
        Integer alreadySeen = FeedStoriesSeen.get(fs);
        if ((alreadySeen != null) && (desiredStoryCount <= alreadySeen)) {
            return false;
        }
            
        Log.d(NBSyncService.class.getName(), "enqueued request for minimum stories: " + desiredStoryCount);
        PendingFeeds.put(fs, desiredStoryCount);
        NbActivity.updateAllActivities();
        return true;
    }

    public static void resetFeeds() {
        ExhaustedFeeds.clear();
        FeedPagesSeen.clear();
        FeedStoriesSeen.clear();
    }

    public static void softInterrupt() {
        Log.d(NBSyncService.class.getName(), "soft stop");
        HaltNow = true;
    }

    public static void resumeFromInterrupt() {
        HaltNow = false;
    }

    @Override
    public void onDestroy() {
        Log.d(this.getClass().getName(), "onDestroy");
        HaltNow = true;
        executor.shutdown();
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

}
