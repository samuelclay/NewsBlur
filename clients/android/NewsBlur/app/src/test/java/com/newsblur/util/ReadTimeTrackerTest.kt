package com.newsblur.util

import com.google.gson.Gson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ReadTimeTrackerTest {
    private val gson = Gson()

    @Test
    fun idleTimeStopsAccumulationUntilActivityResumes() {
        var nowMillis = 0L
        val tracker = ReadTimeTracker(nowMillis = { nowMillis })

        tracker.startTracking("story-1")

        nowMillis += 1_000L
        tracker.tick()
        nowMillis = 121_000L
        tracker.tick()

        assertEquals(1, tracker.getAndResetReadTime("story-1"))

        tracker.recordActivity()
        nowMillis += 1_000L
        tracker.tick()

        assertEquals(1, tracker.getAndResetReadTime("story-1"))
    }

    @Test
    fun harvestingCurrentStoryQueuesItsAccumulatedSeconds() {
        var nowMillis = 0L
        val tracker = ReadTimeTracker(nowMillis = { nowMillis })

        tracker.startTracking("story-1")
        repeat(3) {
            nowMillis += 1_000L
            tracker.tick()
        }

        tracker.harvestCurrentStory()

        val queued = tracker.drainQueuedReadTimesJson()
        assertEquals(mapOf("story-1" to 3.0), decodeReadTimes(queued))
        assertNull(tracker.drainQueuedReadTimesJson())
    }

    @Test
    fun drainingForMarkedStoryIncludesQueuedAndCurrentReadTimes() {
        var nowMillis = 0L
        val tracker = ReadTimeTracker(nowMillis = { nowMillis })

        tracker.queueReadTime("story-1", 4)
        tracker.startTracking("story-2")
        repeat(2) {
            nowMillis += 1_000L
            tracker.tick()
        }

        val queued = tracker.drainReadTimesForMarkedStory("story-2")

        assertEquals(
            mapOf(
                "story-1" to 4.0,
                "story-2" to 2.0,
            ),
            decodeReadTimes(queued),
        )
        assertEquals(0, tracker.getAndResetReadTime("story-2"))
    }

    private fun decodeReadTimes(json: String?): Map<String, Double> =
        gson.fromJson(json, mapType)

    companion object {
        private val mapType = object : com.google.gson.reflect.TypeToken<Map<String, Double>>() {}.type
    }
}
