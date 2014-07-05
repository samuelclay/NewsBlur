package com.newsblur.service;

import android.app.Service;
import android.content.ContentValues;
import android.content.Intent;
import android.os.IBinder;
import android.os.PowerManager;
import android.text.TextUtils;
import android.util.Log;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.activity.NbActivity;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.domain.SocialFeed;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.FeedFolderResponse;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.network.domain.UnreadStoryHashesResponse;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedSet;
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

    private volatile static boolean CleanupRunning = false;
    private volatile static boolean FFSyncRunning = false;
    private volatile static boolean DoCleanup = false;
    private volatile static boolean DoFeedsFolders = false;
    /** Feed sets that we need to sync and how many stories the UI wants for them. */
    private static Map<FeedSet,Integer> PendingFeeds;
    static { PendingFeeds = new HashMap<FeedSet,Integer>(); }
    private static Set<FeedSet> ExhaustedFeeds;
    static { ExhaustedFeeds = new HashSet<FeedSet>(); }

    private volatile static boolean HaltNow = false;

	private APIManager apiManager;
    private BlurDatabaseHelper dbHelper;

    private Set<String> storyHashQueue;
    private Map<FeedSet,Integer> feedPagesSeen;
    private Map<FeedSet,Integer> feedStoriesSeen;

	@Override
	public void onCreate() {
		super.onCreate();
        Log.d(this.getClass().getName(), "onCreate");
		apiManager = new APIManager(this);
        PrefsUtils.checkForUpgrade(this);
        dbHelper = new BlurDatabaseHelper(this);
        storyHashQueue = new HashSet<String>();
        feedPagesSeen = new HashMap<FeedSet,Integer>();
        feedStoriesSeen = new HashMap<FeedSet,Integer>();
        PendingFeeds.clear();
        ExhaustedFeeds.clear();
	}

    /**
     * Called serially, once per "start" of the service.  This serves as a wakeup call
     * that the service should check for outstanding work.
     */
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        HaltNow = false;
        // only perform a sync if the app is actually running or background syncs are enabled
        if (PrefsUtils.isOfflineEnabled(this) || (NbActivity.getActiveActivityCount() > 0)) {
            // Services actually get invoked on the main system thread, and are not
            // allowed to do tangible work.  We spawn a thread to do so.
            new Thread(new Runnable() {
                public void run() {
                    doSync();
                }
            }).start();
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
    private synchronized void doSync() {
        Log.d(this.getClass().getName(), "starting sync . . .");

        PowerManager pm = (PowerManager) getApplicationContext().getSystemService(POWER_SERVICE);
        PowerManager.WakeLock wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, this.getClass().getSimpleName());
        try {
            wl.acquire();

            CleanupRunning = true;
            NbActivity.updateAllActivities();
            if (DoCleanup) {
                Log.d(this.getClass().getName(), "cleaning up stories");
                dbHelper.cleanupStories(PrefsUtils.isKeepOldStories(this));
            }
            CleanupRunning = false;
            NbActivity.updateAllActivities();

            FFSyncRunning = true;
            NbActivity.updateAllActivities();
            if (DoFeedsFolders || PrefsUtils.isTimeToAutoSync(this)) {
                syncMetadata();
                PrefsUtils.updateLastSyncTime(this);
                DoFeedsFolders = false;
            }
            FFSyncRunning = false;
            NbActivity.updateAllActivities();

            syncPendingFeeds();
            NbActivity.updateAllActivities();

            syncUnreads();
            NbActivity.updateAllActivities();

        } catch (Exception e) {
            Log.e(this.getClass().getName(), "Sync error.", e);
        } finally {
            wl.release();
            Log.d(this.getClass().getName(), " . . . sync done");
        }
    }

    /**
     * The very first step of a sync - get the feed/folder list, unread counts, and
     * unread hashes.
     */
    private void syncMetadata() {
        if (HaltNow) return;

        Log.d(this.getClass().getName(), "fetching feeds and folders");
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

        // making the above API call resets pagination on the server
        feedPagesSeen.clear();

        // there is a rare issue with feeds that have no folder.  capture them for debug.
        List<String> debugFeedIds = new ArrayList<String>();

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

        if (HaltNow) return;

        Log.d(this.getClass().getName(), "fetching unread hashes");
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
                        storyHashQueue.add(newHash);
                    }
                    oldUnreadHashes.remove(newHash);
                }
            }
        }

        // mark as read any old stories that were recently read
        dbHelper.markStoryHashesRead(oldUnreadHashes);
    }

    /**
     * The second step of syncing: fetch new unread stories.
     */
    private void syncUnreads() {
        unreadsyncloop: while (storyHashQueue.size() > 0) {
            if (HaltNow) return;

            List<String> hashBatch = new ArrayList(AppConstants.UNREAD_FETCH_BATCH_SIZE);
            batchloop: for (String hash : storyHashQueue) {
                hashBatch.add(hash);
                if (hashBatch.size() >= AppConstants.UNREAD_FETCH_BATCH_SIZE) break batchloop;
            }
            for (String hash : hashBatch) {
                storyHashQueue.remove(hash);
            } 
            StoriesResponse response = apiManager.getStoriesByHash(hashBatch);
            if (response.isError()) {
                Log.e(this.getClass().getName(), "error fetching unreads batch, abandoning sync.");
                break unreadsyncloop;
            }
            dbHelper.insertStories(response);
        }
    }

    private void syncPendingFeeds() {
        feedloop: for (FeedSet fs : PendingFeeds.keySet()) {
            if (HaltNow) return;

            if (ExhaustedFeeds.contains(fs)) {
                Log.i(this.getClass().getName(), "No more stories for feed set: " + fs);
                PendingFeeds.remove(fs);
                continue feedloop;
            }
            
            if (!feedPagesSeen.containsKey(fs)) {
                feedPagesSeen.put(fs, 0);
                feedStoriesSeen.put(fs, 0);
            }
            int pageNumber = feedPagesSeen.get(fs);
            int totalStoriesSeen = feedStoriesSeen.get(fs);

            StoryOrder order = PrefsUtils.getStoryOrder(this, fs);
            ReadFilter filter = PrefsUtils.getReadFilter(this, fs);
            
            pageloop: while (totalStoriesSeen < PendingFeeds.get(fs)) {
                if (HaltNow) return;

                pageNumber++;
                StoriesResponse apiResponse /*= apiManager.getStoriesForFeed(feedId, pageNumber, order, filter)*/;
            
                if (! isStoryResponseGood(apiResponse)) break feedloop;

                feedPagesSeen.put(fs, pageNumber);
                dbHelper.insertStories(apiResponse);
            
                if (apiResponse.stories.length == 0) {
                    ExhaustedFeeds.add(fs);
                    break pageloop;
                } else {
                    totalStoriesSeen += apiResponse.stories.length;
                    feedStoriesSeen.put(fs, totalStoriesSeen);
                }
            }

            PendingFeeds.remove(fs);
        }
    }

    private boolean isStoryResponseGood(StoriesResponse response) {
        if (response.isError()) {
            Log.e(this.getClass().getName(), "Error response received loading stories.");
            Toast.makeText(this, response.getErrorMessage(this.getString(R.string.toast_error_loading_stories)), Toast.LENGTH_LONG).show();
            return false;
        }
        if (response.stories == null) {
            Log.e(this.getClass().getName(), "Null stories member received while loading stories with no error found.");
            Toast.makeText(this, R.string.toast_error_loading_stories, Toast.LENGTH_LONG).show();
            return false;
        }
        return true;
    }

    /**
     * Is the main feed/folder list sync running?
     */
    public static boolean isFeedFolderSyncRunning() {
        return FFSyncRunning;
    }

    /**
     * Force a refresh of feed/folder data on the next sync, even if enough time
     * hasn't passed for an autosync.
     */
    public static void forceFeedsFolders() {
        DoFeedsFolders = true;
    }

    /**
     * Indicates whether now is an appropriate time to perform story cleanup because the user is
     * not actively seeing stories. (e.g. they are on the feed/folder activity)
     */
    public static void enableCleanup(boolean doCleanup) {
        DoCleanup = doCleanup;
    }

    /**
     * Requests that the service fetch additional stories for the specified feed/folder. Returns
     * true if more will be fetched or false if there are none remaining for that feed.
     *
     * @param desiredStoryCount the minimum number of stories to fetch.
     */
    public static boolean requestMoreForFeed(FeedSet fs, int desiredStoryCount) {
        if (ExhaustedFeeds.contains(fs)) return false;
        PendingFeeds.put(fs, desiredStoryCount);
        return true;
    }

    @Override
    public void onDestroy() {
        Log.d(this.getClass().getName(), "onDestroy");
        HaltNow = true;
        dbHelper.close();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

}
