package com.newsblur.service

import com.newsblur.database.DatabaseConstants
import com.newsblur.service.NbSyncManager.UPDATE_TEXT
import com.newsblur.util.AppConstants
import com.newsblur.util.FeedUtils.Companion.inferFeedId
import com.newsblur.util.Log
import com.newsblur.util.NBScope
import java.util.Collections
import java.util.concurrent.atomic.AtomicBoolean
import java.util.regex.Pattern

class OriginalTextService(parent: NBSyncService) : SubService(parent, NBScope) {

    override fun exec() {
        if (!activelyRunningFlag.compareAndSet(false, true)) {
            return
        }
        try {
            while (true) {
                if (parent.stopSync()) return
                fetchBatch()
                synchronized(Hashes) {
                    if (Hashes.isEmpty()) return
                }
            }
        } finally {
            activelyRunningFlag.set(false)
        }
    }

    private fun fetchBatch() {
        val fetchedHashes: MutableSet<String> = HashSet()
        val batch: MutableSet<String> = HashSet(AppConstants.ORIGINAL_TEXT_BATCH_SIZE)

        synchronized(Hashes) {
            for (hash in Hashes) {
                batch.add(hash)
                if (batch.size >= AppConstants.ORIGINAL_TEXT_BATCH_SIZE) break
            }
        }

        try {
            for (hash in batch) {
                if (parent.stopSync()) break
                fetchedHashes.add(hash)
                var result: String? = null
                val response = parent.apiManager.getStoryText(inferFeedId(hash), hash)
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
                    parent.dbHelper.putStoryText(hash, result)
                    // scan for potentially cache-able images in the extracted 'text'
                    val imgTagMatcher = imgSniff.matcher(result)
                    while (imgTagMatcher.find()) {
                        parent.imagePrefetchService.addUrl(imgTagMatcher.group(2))
                    }
                }
            }
        } finally {
            synchronized(Hashes) {
                Hashes.removeAll(fetchedHashes)
            }
            parent.sendSyncUpdate(UPDATE_TEXT)
        }
    }

    companion object {

        private val activelyRunningFlag = AtomicBoolean(false)

        @JvmStatic
        val activelyRunning: Boolean
            get() = activelyRunningFlag.get()

        // special value for when the API responds that it could fatally could not fetch text
        const val NULL_STORY_TEXT: String = "__NULL_STORY_TEXT__"

        private val imgSniff: Pattern = Pattern.compile("<img[^>]*src=(['\"])((?:(?!\\1).)*)\\1[^>]*>", Pattern.CASE_INSENSITIVE)

        private val Hashes: MutableSet<String> = Collections.synchronizedSet(HashSet())

        fun addHash(hash: String) {
            Hashes.add(hash)
        }

        @JvmStatic
        val pendingCount: Int
            get() = (Hashes.size)

        @JvmStatic
        fun clear() {
            Hashes.clear()
        }
    }
}

