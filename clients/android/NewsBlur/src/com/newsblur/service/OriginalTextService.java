package com.newsblur.service;

import static com.newsblur.service.NBSyncReceiver.UPDATE_TEXT;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.network.domain.StoryTextResponse;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedUtils;

import java.util.HashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class OriginalTextService extends SubService {

    public static boolean activelyRunning = false;

    // special value for when the API responds that it could fatally could not fetch text
    public static final String NULL_STORY_TEXT = "__NULL_STORY_TEXT__";

    private static final Pattern imgSniff = Pattern.compile("<img[^>]*src=(['\"])((?:(?!\\1).)*)\\1[^>]*>", Pattern.CASE_INSENSITIVE);

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
        activelyRunning = true;
        try {
            while ((Hashes.size() > 0) || (PriorityHashes.size() > 0)) {
                if (parent.stopSync()) return;
                fetchBatch(PriorityHashes);
                fetchBatch(Hashes);
            }
        } finally {
            activelyRunning = false;
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
                if (parent.stopSync()) break fetchloop;
                fetchedHashes.add(hash);
                String result = null;
                StoryTextResponse response = parent.apiManager.getStoryText(FeedUtils.inferFeedId(hash), hash);
                if (response != null) {
                    if (response.originalText == null) {
                        // a null value in an otherwise valid response to this call indicates a fatal
                        // failure to extract text and should be recorded so the UI can inform the
                        // user and switch them back to a valid view mode
                        result = NULL_STORY_TEXT;
                    } else if (response.originalText.length() >= DatabaseConstants.MAX_TEXT_SIZE) {
                        // this API can occasionally return story texts that are much too large to query
                        // from the DB.  stop insertion to prevent poisoning the DB and the cursor lifecycle
                        com.newsblur.util.Log.w(this, "discarding too-large story text. hash " + hash + " size " + response.originalText.length());
                        result = NULL_STORY_TEXT;
                    } else {
                        result = response.originalText;
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
            parent.sendSyncUpdate(UPDATE_TEXT);
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

}
        
