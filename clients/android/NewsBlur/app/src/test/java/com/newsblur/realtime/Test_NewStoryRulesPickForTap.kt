package com.newsblur.realtime

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class Test_NewStoryRulesPickForTap {
    // Sam: past 20, the list keeps "the 20 latest-dated stories": a newer arrival displaces the oldest one kept, an
    // older one is only counted, and the tap shows them newest first, as if the list loaded right then.
    @Test
    fun test_newestFirstKeepsTheTwentyLatestDatedWithNewerArrivalsDisplacingTheOldest() {
        val waiting = LinkedHashMap<String, Long>()
        (1..20).forEach { waiting["1:kept$it"] = 1_000L + it }
        waiting["1:newer"] = 5_000L
        waiting["1:older"] = 10L

        val picked = NewStoryRules.pickForTap(waiting, 20, newestFirst = true)

        assertEquals(20, picked.size)
        assertEquals("1:newer", picked.first())
        assertEquals((20 downTo 2).map { "1:kept$it" }, picked.drop(1))
    }

    // An oldest-first list keeps its 20 oldest loaded: past the cap only an arrival older than the newest of them gets
    // loaded, and a same-dated one is only counted, in either order.
    @Test
    fun test_oldestFirstLoadsOnlyOlderArrivalsPastTheCapAndTiesAreCounted() {
        val held = listOf(100L, 200L, 300L)

        assertTrue(NewStoryRules.belongsAmongLoaded(250L, held, 3, newestFirst = false))
        assertFalse(NewStoryRules.belongsAmongLoaded(400L, held, 3, newestFirst = false))
        assertFalse(NewStoryRules.belongsAmongLoaded(300L, held, 3, newestFirst = false))
        assertFalse(NewStoryRules.belongsAmongLoaded(100L, held, 3, newestFirst = true))
    }

    // An oldest-first list gains the oldest-dated waiting stories at its end, in its own order.
    @Test
    fun test_oldestFirstTakesTheOldestDatedInOrder() {
        val waiting = mapOf("1:c" to 300L, "1:a" to 100L, "1:d" to 400L, "1:b" to 200L)

        assertEquals(listOf("1:a", "1:b"), NewStoryRules.pickForTap(waiting, 2, newestFirst = false))
    }
}
