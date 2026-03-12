package com.newsblur.util

import com.newsblur.network.APIConstants
import com.newsblur.network.NetworkClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONObject
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ReadTimeTracker @Inject constructor(
    private val networkClient: NetworkClient,
) {
    var currentStoryHash: String? = null
        private set

    // Hash saved across background transitions so tracking can resume on foreground
    private var backgroundedStoryHash: String? = null

    private val readTimes = mutableMapOf<String, Int>()
    private val queuedReadTimes = mutableMapOf<String, Int>()
    private var lastActivityMs: Long = 0L
    var isAppActive: Boolean = true
    private var timerJob: Job? = null

    fun startTracking(storyHash: String) {
        stopTracking()
        synchronized(this) {
            currentStoryHash = storyHash
            lastActivityMs = System.currentTimeMillis()
        }
        timerJob = CoroutineScope(Dispatchers.Default).launch {
            while (isActive) {
                delay(1000)
                synchronized(this@ReadTimeTracker) {
                    val hash = currentStoryHash ?: return@synchronized
                    if (!isAppActive) return@synchronized
                    if (System.currentTimeMillis() - lastActivityMs < IDLE_THRESHOLD_MS) {
                        readTimes[hash] = (readTimes[hash] ?: 0) + 1
                    }
                }
            }
        }
    }

    fun stopTracking() {
        timerJob?.cancel()
        timerJob = null
        synchronized(this) {
            currentStoryHash = null
        }
    }

    fun recordActivity() {
        synchronized(this) {
            lastActivityMs = System.currentTimeMillis()
        }
    }

    fun getAndResetReadTime(storyHash: String): Int {
        synchronized(this) {
            return readTimes.remove(storyHash) ?: 0
        }
    }

    fun queueReadTime(storyHash: String, seconds: Int) {
        synchronized(this) {
            queuedReadTimes[storyHash] = (queuedReadTimes[storyHash] ?: 0) + seconds
        }
    }

    fun consumeQueuedReadTimesJSON(): String? {
        synchronized(this) {
            if (queuedReadTimes.isEmpty()) return null
            val json = JSONObject(queuedReadTimes.mapValues { it.value } as Map<*, *>).toString()
            queuedReadTimes.clear()
            return json
        }
    }

    fun restoreQueuedReadTimes(json: String) {
        synchronized(this) {
            val obj = JSONObject(json)
            for (key in obj.keys()) {
                queuedReadTimes[key] = (queuedReadTimes[key] ?: 0) + obj.getInt(key)
            }
        }
    }

    fun harvestAndFlush() {
        synchronized(this) {
            currentStoryHash?.let { hash ->
                val seconds = readTimes.remove(hash) ?: 0
                if (seconds > 0) {
                    queuedReadTimes[hash] = (queuedReadTimes[hash] ?: 0) + seconds
                }
            }
        }
        stopTracking()
        flushReadTimes()
    }

    /**
     * Harvest accumulated time and flush, but remember which story was being
     * tracked so [resumeFromBackground] can restart the timer.
     */
    fun harvestForBackground() {
        synchronized(this) {
            backgroundedStoryHash = currentStoryHash
        }
        harvestAndFlush()
    }

    /**
     * Restart tracking for the story that was active when the app went to background.
     */
    fun resumeFromBackground() {
        val hash: String?
        synchronized(this) {
            hash = backgroundedStoryHash
            backgroundedStoryHash = null
        }
        hash?.let { startTracking(it) }
    }

    private fun flushReadTimes() {
        val json: String
        synchronized(this) {
            if (queuedReadTimes.isEmpty()) return
            json = JSONObject(queuedReadTimes.mapValues { it.value } as Map<*, *>).toString()
            queuedReadTimes.clear()
        }
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val values = com.newsblur.domain.ValueMultimap()
                values.put(APIConstants.PARAMETER_READ_TIMES, json)
                val urlString = APIConstants.buildUrl(APIConstants.PATH_MARK_STORIES_READ)
                val response = networkClient.post(urlString, values)
                if (response.isError) {
                    Log.w(this@ReadTimeTracker, "Flush read times API error, restoring")
                    restoreQueuedReadTimes(json)
                }
            } catch (e: Exception) {
                Log.e(this@ReadTimeTracker, "Failed to flush read times", e)
                restoreQueuedReadTimes(json)
            }
        }
    }

    companion object {
        private const val IDLE_THRESHOLD_MS = 120_000L
    }
}
