package com.newsblur.util

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.ObjectInputStream
import java.io.ObjectOutputStream
import java.io.Serializable
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class Test_FeedSetSocialSerialization {
    @Test
    fun test_compact_social_feed_uses_a_platform_serializable_map() {
        val source = FeedSet.multipleSocialFeeds(setOf("24974", "42"))
        source.multipleSocialFeeds["24974"] = "tante"
        source.multipleSocialFeeds["42"] = "reader"
        val restored = FeedSet.fromCompactSerial(source.toCompactSerial())

        // FeedSet.java crosses Intent boundaries; R8 strips Gson's private writeReplace hook.
        val socialFeeds = restored.multipleSocialFeeds
        assertTrue("Social feed transport must not depend on Gson serialization hooks", socialFeeds.javaClass.name.startsWith("java.util."))
        assertTrue(socialFeeds is Serializable)
        assertEquals(mapOf("24974" to "tante", "42" to "reader"), javaRoundTrip(restored).multipleSocialFeeds)
    }

    @Test
    fun test_shared_story_launch_keeps_identity_search_and_filters_after_compact_round_trip() {
        val source = FeedSet.singleSocialFeed("24974", "tante").apply {
            searchQuery = "a shared story"
            stateFilterOverride = StateFilter.SOME
            readFilterOverride = ReadFilter.UNREAD
            isFilterSaved = true
        }
        val restored = javaRoundTrip(FeedSet.fromCompactSerial(source.toCompactSerial()))

        assertEquals("24974", restored.singleSocialFeed.key)
        assertEquals("tante", restored.singleSocialFeed.value)
        assertEquals("a shared story", restored.searchQuery)
        assertEquals(StateFilter.SOME, restored.stateFilterOverride)
        assertEquals(ReadFilter.UNREAD, restored.readFilterOverride)
        assertTrue(restored.isFilterSaved)
    }

    @Test
    fun test_compact_all_shared_and_regular_feeds_remain_serializable() {
        val allShared = javaRoundTrip(FeedSet.fromCompactSerial(FeedSet.allSocialFeeds().toCompactSerial()))
        val regular = javaRoundTrip(FeedSet.fromCompactSerial(FeedSet.singleFeed("42").toCompactSerial()))
        assertTrue(allShared.isAllSocial)
        assertEquals("42", regular.singleFeed)
    }

    private fun javaRoundTrip(feedSet: FeedSet): FeedSet {
        val bytes = ByteArrayOutputStream()
        ObjectOutputStream(bytes).use { it.writeObject(feedSet) }
        return ObjectInputStream(ByteArrayInputStream(bytes.toByteArray())).use { it.readObject() as FeedSet }
    }
}
