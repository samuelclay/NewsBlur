package com.newsblur.service;

import android.util.Log;

import com.newsblur.domain.Story;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.network.domain.UnreadStoryHashesResponse;
import com.newsblur.util.AppConstants;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map.Entry;
import java.util.Set;

public class UnreadsService extends SubService {

    private static volatile boolean Running = false;

    /** Unread story hashes the API listed that we do not appear to have locally yet. */
    private static Set<String> StoryHashQueue;
    static { StoryHashQueue = new HashSet<String>(); }

    public UnreadsService(NBSyncService parent) {
        super(parent);
    }

    @Override
    protected void exec() {
        // only use the unread status API if the user is premium
        if (parent.isPremium != Boolean.TRUE) return;

        gotWork();
        syncUnreadList();

        if (StoryHashQueue.size() < 1) return;

        gotWork();
        getNewUnreadStories();
    }

    private void syncUnreadList() {
        UnreadStoryHashesResponse unreadHashes = parent.apiManager.getUnreadStoryHashes();
        
        // note all the stories we thought were unread before. if any fail to appear in
        // the API request for unreads, we will mark them as read
        List<String> oldUnreadHashes = parent.dbHelper.getUnreadStoryHashes();

        for (Entry<String, String[]> entry : unreadHashes.unreadHashes.entrySet()) {
            String feedId = entry.getKey();
            // ignore unreads from orphaned feeds
            if( ! parent.orphanFeedIds.contains(feedId)) {
                // only fetch the reported unreads if we don't already have them
                List<String> existingHashes = parent.dbHelper.getStoryHashesForFeed(feedId);
                for (String newHash : entry.getValue()) {
                    if (!existingHashes.contains(newHash)) {
                        StoryHashQueue.add(newHash);
                    }
                    oldUnreadHashes.remove(newHash);
                }
            }
        }

        parent.dbHelper.markStoryHashesRead(oldUnreadHashes);
    }

    private void getNewUnreadStories() {
        unreadsyncloop: while (StoryHashQueue.size() > 0) {
            if (parent.stopSync()) return;

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

    public static void clearHashes() {
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
        
