package com.newsblur.service;

import android.util.Log;

import com.newsblur.activity.NbActivity;
import com.newsblur.network.domain.StoryTextResponse;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedUtils;

import java.util.HashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class OriginalTextService extends SubService {

    // special value for when the API responds that it could fatally could not fetch text
    public static final String NULL_STORY_TEXT = "__NULL_STORY_TEXT__";

    private static final Pattern imgSniff = Pattern.compile("<img[^>]*src=(['\"])((?:(?!\\1).)*)\\1[^>]*>", Pattern.CASE_INSENSITIVE);

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
                fetchedHashes.add(hash);
                String result = null;
                StoryTextResponse response = parent.apiManager.getStoryText(FeedUtils.inferFeedId(hash), hash);
                if (response != null) {
                    if (response.originalText != null) {
                        result = response.originalText;
                    } else {
                        // a null value in an otherwise valid response to this call indicates a fatal
                        // failure to extract text and should be recorded so the UI can inform the
                        // user and switch them back to a valid view mode
                        result = NULL_STORY_TEXT;
                    }
                }
                if (result != null) {   
                    // store the fetched text in the DB
                    parent.dbHelper.putStoryText(hash, result);
                    // scan for potentially cache-able images in the extracted 'text'
                    Matcher imgTagMatcher = imgSniff.matcher(result);
                    while (imgTagMatcher.find()) {
                        parent.imagePrefetchService.addUrl(imgTagMatcher.group(2));
                    }
                }
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

    @Override
    public boolean haveWork() {
        return (getPendingCount() > 0);
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
        
