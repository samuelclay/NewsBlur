package com.newsblur.util

import android.os.SystemClock
import com.google.gson.Gson

class ReadTimeTracker(
    private val nowMillis: () -> Long = SystemClock::elapsedRealtime,
    private val idleThresholdMillis: Long = IDLE_THRESHOLD_MILLIS,
) {
    private val gson = Gson()
    private val readTimes = mutableMapOf<String, Int>()
    private val queuedReadTimes = linkedMapOf<String, Int>()
    private var lastActivityMillis: Long = nowMillis()

    @get:Synchronized
    var currentStoryHash: String? = null
        private set

    @Synchronized
    fun startTracking(storyHash: String) {
        if (storyHash.isBlank()) return

        currentStoryHash = storyHash
        lastActivityMillis = nowMillis()
    }

    @Synchronized
    fun stopTracking() {
        currentStoryHash = null
    }

    @Synchronized
    fun recordActivity() {
        lastActivityMillis = nowMillis()
    }

    @Synchronized
    fun tick() {
        val storyHash = currentStoryHash ?: return
        if (nowMillis() - lastActivityMillis >= idleThresholdMillis) return

        readTimes[storyHash] = (readTimes[storyHash] ?: 0) + 1
    }

    @Synchronized
    fun getAndResetReadTime(storyHash: String): Int = readTimes.remove(storyHash) ?: 0

    @Synchronized
    fun queueReadTime(storyHash: String, seconds: Int) {
        if (storyHash.isBlank() || seconds <= 0) return

        queuedReadTimes[storyHash] = (queuedReadTimes[storyHash] ?: 0) + seconds
    }

    @Synchronized
    fun harvestCurrentStory() {
        val storyHash = currentStoryHash ?: return
        val seconds = getAndResetReadTime(storyHash)
        if (seconds > 0) {
            queueReadTime(storyHash, seconds)
        }
    }

    @Synchronized
    fun drainReadTimesForMarkedStory(storyHash: String): String? {
        if (storyHash.isBlank()) return drainQueuedReadTimesJson()

        val seconds = getAndResetReadTime(storyHash)
        if (seconds > 0) {
            queueReadTime(storyHash, seconds)
        }

        return drainQueuedReadTimesJson()
    }

    @Synchronized
    fun drainQueuedReadTimesJson(): String? {
        if (queuedReadTimes.isEmpty()) return null

        val readTimesToSend = LinkedHashMap(queuedReadTimes)
        queuedReadTimes.clear()
        return gson.toJson(readTimesToSend)
    }

    companion object {
        const val IDLE_THRESHOLD_MILLIS: Long = 120_000L
    }
}
