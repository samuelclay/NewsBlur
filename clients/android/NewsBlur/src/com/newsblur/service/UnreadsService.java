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
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.Map.Entry;
import java.util.Set;

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
        // get unread hashes and dates from the API
        UnreadStoryHashesResponse unreadHashes = parent.apiManager.getUnreadStoryHashes();
        
        if (parent.stopSync()) return;

        // get all the stories we thought were unread before. we should not enqueue a fetch of
        // stories we already have.  also, if any existing unreads fail to appear in
        // the set of unreads from the API, we will mark them as read. note that this collection
        // will be searched many times for new unreads, so it should be a Set, not a List.
        Set<String> oldUnreadHashes = parent.dbHelper.getUnreadStoryHashesAsSet();

        // a place to store and then sort unread hashes we aim to fetch. note the member format
        // is made to match the format of the API response (a list of [hash, date] tuples). it
        // is crucial that we re-use objects as much as possible to avoid memory churn
        List<String[]> sortationList = new ArrayList<String[]>();

        // process the api response, both bookkeeping no-longer-unread stories and populating
        // the sortation list we will use to create the fetch list for step two
        feedloop: for (Entry<String, List<String[]>> entry : unreadHashes.unreadHashes.entrySet()) {
            // the API gives us a list of unreads, split up by feed ID. the unreads are tuples of
            // story hash and date
            String feedId = entry.getKey();
            // ignore unreads from orphaned feeds
            if (parent.orphanFeedIds.contains(feedId)) continue feedloop;
            for (String[] newUnread : entry.getValue()) {
                // only fetch the reported unreads if we don't already have them
                if (!oldUnreadHashes.contains(newUnread[0])) {
                    sortationList.add(newUnread);
                } else {
                    oldUnreadHashes.remove(newUnread[0]);
                }
            }
        }

        // now sort the unreads we need to fetch so they are fetched roughly in the order
        // the user is likely to read them.  if the user reads newest first, those come first.
        final boolean sortNewest = (PrefsUtils.getDefaultStoryOrder(parent) == StoryOrder.NEWEST);
        // custom comparator that understands to sort tuples by the value of the second element
        Comparator<String[]> hashSorter = new Comparator<String[]>() {
            public int compare(String[] lhs, String[] rhs) {
                // element [1] of the unread tuple is the date in epoch seconds
                if (sortNewest) {
                    return rhs[1].compareTo(lhs[1]);
                } else {
                    return lhs[1].compareTo(rhs[1]);
                }
            }
            public boolean equals(Object object) {
                return false;
            }
        };
        Collections.sort(sortationList, hashSorter);

        // now that we have the sorted set of hashes, turn them into a list over which we 
        // can iterate to fetch them
        StoryHashQueue.clear();
        for (String[] tuple : sortationList) {
            // element [0] of the tuple is the story hash, the rest can safely be thown out
            StoryHashQueue.add(tuple[0]);
        }

        if (parent.stopSync()) return;

        // any stories that we previously thought to be unread but were not found in the
        // list, mark them read now
        parent.dbHelper.markStoryHashesRead(oldUnreadHashes);
    }

    private void getNewUnreadStories() {
        int totalCount = StoryHashQueue.size();
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
                if (story.thumbnailUrl != null) {
                    parent.imagePrefetchService.addThumbnailUrl(story.thumbnailUrl);
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
        
