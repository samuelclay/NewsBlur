package com.newsblur.service;

import android.util.Log;

import com.newsblur.activity.NbActivity;
import com.newsblur.network.domain.StoryTextResponse;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedUtils;

import java.util.HashSet;
import java.util.Set;

public class OriginalTextService extends SubService {

    private static volatile boolean Running = false;

    /** story hashes we need to fetch (from newly found stories) */
    private static Set<String> Hashes;
    static {Hashes = new HashSet<String>();}
    /** story hashes we should fetch ASAP (they are waiting on-screen) */
    private static Set<String> PriorityHashes;
    static {PriorityHashes = new HashSet<String>();}

    public OriginalTextService(NBSyncService parent) {
        super(parent);
    }

    @Override
    protected void exec() {
        while ((Hashes.size() > 0) || (PriorityHashes.size() > 0)) {
            if (parent.stopSync()) return;
            gotWork();
            fetchBatch(PriorityHashes);
            fetchBatch(Hashes);
        }
    }

    private void fetchBatch(Set<String> hashes) {
        Set<String> fetchedHashes = new HashSet<String>();
        Set<String> batch = new HashSet<String>(AppConstants.IMAGE_PREFETCH_BATCH_SIZE);
        batchloop: for (String hash : hashes) {
            batch.add(hash);
            if (batch.size() >= AppConstants.IMAGE_PREFETCH_BATCH_SIZE) break batchloop;
        }
        try {
            fetchloop: for (String hash : batch) {
                if (parent.stopSync()) return;
                String result = "";
                StoryTextResponse response = parent.apiManager.getStoryText(FeedUtils.inferFeedId(hash), hash);
                if ((response != null) && (response.originalText != null)) {
                    result = response.originalText;
                }
                parent.dbHelper.putStoryText(hash, result);
                fetchedHashes.add(hash);
            }
        } finally {
            gotData(NbActivity.UPDATE_TEXT);
            hashes.removeAll(fetchedHashes);
        }
    }

    public static void addHash(String hash) {
        Hashes.add(hash);
    }

    public static void addPriorityHash(String hash) {
        PriorityHashes.add(hash);
    }

    public static int getPendingCount() {
        return (Hashes.size() + PriorityHashes.size());
    }

    public static void clear() {
        Hashes.clear();
        PriorityHashes.clear();
    }

    public static boolean running() {
        return Running;
    }
    @Override
    protected void setRunning(boolean running) {
        Running = running;
    }
    @Override
    public boolean isRunning() {
        return Running;
    }

}
        
