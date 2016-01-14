package com.newsblur.service;

import android.util.Log;

import com.newsblur.domain.Story;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.network.domain.UnreadStoryHashesResponse;
import com.newsblur.util.AppConstants;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StoryOrder;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.NavigableMap;
import java.util.TreeMap;

public class UnreadsService extends SubService {

    private static volatile boolean Running = false;

    private static volatile boolean doMetadata = false;

    /** Unread story hashes the API listed that we do not appear to have locally yet. */
    private static List<String> StoryHashQueue;
    static { StoryHashQueue = new ArrayList<String>(); }

    public UnreadsService(NBSyncService parent) {
        super(parent);
    }

    @Override
    protected void exec() {
        if (doMetadata) {
            gotWork();
            syncUnreadList();
            doMetadata = false;
        }

        if (StoryHashQueue.size() < 1) return;

        getNewUnreadStories();
    }

    private void syncUnreadList() {
        // a self-sorting map with keys based upon the timestamp of the story returned by
        // the unreads API, concatenated with the hash to disambiguate duplicate timestamps.
        // values are the actual story hash, which will be extracted once we have processed
        // all hashes.
        NavigableMap<String,String> sortingMap = new TreeMap<String,String>();
        UnreadStoryHashesResponse unreadHashes = parent.apiManager.getUnreadStoryHashes();
        
        // note all the stories we thought were unread before. if any fail to appear in
        // the API request for unreads, we will mark them as read
        List<String> oldUnreadHashes = parent.dbHelper.getUnreadStoryHashes();

        // process the api response, both bookkeeping no-longer-unread stories and populating
        // the sortation map we will use to create the fetch list for step two
        for (Entry<String, List<String[]>> entry : unreadHashes.unreadHashes.entrySet()) {
            String feedId = entry.getKey();
            // ignore unreads from orphaned feeds
            if( ! parent.orphanFeedIds.contains(feedId)) {
                // only fetch the reported unreads if we don't already have them
                List<String> existingHashes = parent.dbHelper.getStoryHashesForFeed(feedId);
                for (String[] newHash : entry.getValue()) {
                    if (!existingHashes.contains(newHash[0])) {
                        sortingMap.put(newHash[1]+newHash[0], newHash[0]);
                    }
                    oldUnreadHashes.remove(newHash[0]);
                }
            }
        }

        // now that we have the sorted set of hashes, turn them into a list over which we 
        // can iterate to fetch them
        if (PrefsUtils.getDefaultStoryOrder(parent) == StoryOrder.NEWEST) {
            // if the user reads newest-first by default, reverse the download order
            sortingMap = sortingMap.descendingMap();
        }
        StoryHashQueue.clear();
        for (Map.Entry<String,String> entry : sortingMap.entrySet()) {
            StoryHashQueue.add(entry.getValue());
        }

        // any stories that we previously thought to be unread but were not found in the
        // list, mark them read now
        parent.dbHelper.markStoryHashesRead(oldUnreadHashes);
    }

    private void getNewUnreadStories() {
        unreadsyncloop: while (StoryHashQueue.size() > 0) {
            if (parent.stopSync()) return;
            if(!PrefsUtils.isOfflineEnabled(parent)) return;
            gotWork();
            startExpensiveCycle();

            List<String> hashBatch = new ArrayList(AppConstants.UNREAD_FETCH_BATCH_SIZE);
            batchloop: for (String hash : StoryHashQueue) {
                hashBatch.add(hash);
                if (hashBatch.size() >= AppConstants.UNREAD_FETCH_BATCH_SIZE) break batchloop;
            }
            StoriesResponse response = parent.apiManager.getStoriesByHash(hashBatch);
            if (! isStoryResponseGood(response)) {
                Log.e(this.getClass().getName(), "error fetching unreads batch, abandoning sync.");
                break unreadsyncloop;
            }
            parent.insertStories(response);
            for (String hash : hashBatch) {
                StoryHashQueue.remove(hash);
            } 

            for (Story story : response.stories) {
                if (story.imageUrls != null) {
                    for (String url : story.imageUrls) {
                        parent.imagePrefetchService.addUrl(url);
                    }
                }
                DefaultFeedView mode = PrefsUtils.getDefaultFeedViewForFeed(parent, story.feedId);
                if (mode == DefaultFeedView.TEXT) {
                    parent.originalTextService.addHash(story.storyHash);
                }
            }
            parent.originalTextService.start(startId);
            parent.imagePrefetchService.start(startId);
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

    public static void clear() {
        StoryHashQueue.clear();
    }

    /**
     * Describe the number of unreads left to be synced or return an empty message (space padded).
     */
    public static String getPendingCount() {
        int c = StoryHashQueue.size();
        if (c < 1) {
            return " ";
        } else {
            return " " + c + " ";
        }
    }

    public static void doMetadata() {
        doMetadata = true;
    }

    public static boolean isDoMetadata() {
        return doMetadata;
    }

    public static boolean running() {
        return Running;
    }
    @Override
    protected void setRunning(boolean running) {
        Running = running;
    }
    @Override
    protected boolean isRunning() {
        return Running;
    }

}
        
