package com.newsblur.util

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class Test_MarkAllReadConfirmation {
    @Test fun test_all_site_stories_always_requires_confirmation() {
        for (preference in MarkAllReadConfirmation.entries) {
            assertTrue(preference.feedSetRequiresConfirmation(FeedSet.allFeeds()))
        }
    }

    @Test fun test_feed_and_folder_confirmation_still_follow_the_preference() {
        val feed = FeedSet.singleFeed("11")
        val folder = FeedSet.folder("Folder", setOf("11", "22"))
        assertFalse(MarkAllReadConfirmation.NONE.feedSetRequiresConfirmation(feed))
        assertFalse(MarkAllReadConfirmation.NONE.feedSetRequiresConfirmation(folder))
        assertFalse(MarkAllReadConfirmation.FOLDER_ONLY.feedSetRequiresConfirmation(feed))
        assertTrue(MarkAllReadConfirmation.FOLDER_ONLY.feedSetRequiresConfirmation(folder))
        assertTrue(MarkAllReadConfirmation.FEED_AND_FOLDER.feedSetRequiresConfirmation(feed))
    }
}
