package com.newsblur.service

import com.newsblur.database.DatabaseConstants
import com.newsblur.service.NbSyncManager.UPDATE_TEXT
import com.newsblur.util.AppConstants
import com.newsblur.util.FeedUtils.Companion.inferFeedId
import com.newsblur.util.Log
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.isActive
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.regex.Pattern

class OriginalTextSubService(delegate: SyncServiceDelegate) : SyncSubService(delegate) {

    override suspend fun execute() = coroutineScope {
        setServiceState(ServiceState.OriginalTextSync)

        try {
            while (isActive) {
                val batch = storyHashes.take(AppConstants.ORIGINAL_TEXT_BATCH_SIZE)

                if (batch.isEmpty()) break

                fetchBatch(batch)

                sendSyncUpdate(UPDATE_TEXT)
            }
        } finally {
            setServiceStateIdleIf(ServiceState.OriginalTextSync)
        }
    }

    private suspend fun fetchBatch(batch: List<String>) = coroutineScope {
        for (hash in batch) {
            ensureActive()
            var result: String? = null
            val response = apiManager.getStoryText(inferFeedId(hash), hash)
            if (response != null) {
                if (response.originalText == null) {
                    // a null value in an otherwise valid response to this call indicates a fatal
                    // failure to extract text and should be recorded so the UI can inform the
                    // user and switch them back to a valid view mode
                    result = NULL_STORY_TEXT
                } else if (response.originalText.length >= DatabaseConstants.MAX_TEXT_SIZE) {
                    // this API can occasionally return story texts that are much too large to query
                    // from the DB.  stop insertion to prevent poisoning the DB and the cursor lifecycle
                    Log.w(this, "discarding too-large story text. hash " + hash + " size " + response.originalText.length)
                    result = NULL_STORY_TEXT
                } else {
                    result = response.originalText
                }
            }

            if (result != null) {
                // store the fetched text in the DB
                dbHelper.putStoryText(hash, result)
                // scan for potentially cache-able images in the extracted 'text'
                val imgTagMatcher = imgSniff.matcher(result)
                while (imgTagMatcher.find()) {
                    addImageUrlToPrefetch(imgTagMatcher.group(2))
                }
            }

            storyHashes.remove(hash)
        }
    }

    companion object {
        // special value for when the API responds that it could fatally could not fetch text
        const val NULL_STORY_TEXT: String = "__NULL_STORY_TEXT__"

        private val imgSniff: Pattern = Pattern.compile("<img[^>]*src=(['\"])((?:(?!\\1).)*)\\1[^>]*>", Pattern.CASE_INSENSITIVE)

        private val storyHashes = ConcurrentLinkedQueue<String>()

        fun addHash(hash: String) = storyHashes.add(hash)

        fun clear() {
            storyHashes.clear()
        }

        val pendingCount get() = storyHashes.size
    }
}