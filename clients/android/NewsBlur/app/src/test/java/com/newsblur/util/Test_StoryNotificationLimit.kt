package com.newsblur.util

import com.newsblur.util.StoryNotificationLimit.Showing
import org.junit.Assert.assertEquals
import org.junit.Test

class Test_StoryNotificationLimit {
    private fun showing(vararg storyTimes: Long) = storyTimes.map { Showing(id = it.toInt(), storyTime = it, storyHash = "1:$it") }

    @Test fun test_sixth_story_takes_the_place_of_the_oldest_one_showing() {
        // NotificationUtils.java shows five stories at most; a pushed sixth must not pile up in the shade.
        val overflow = StoryNotificationLimit.toDismissForOneMore(showing(30, 10, 50, 20, 40), limit = 5)

        assertEquals(listOf("1:10"), overflow.map { it.storyHash })
    }

    @Test fun test_nothing_is_dismissed_while_there_is_room() {
        assertEquals(emptyList<Showing>(), StoryNotificationLimit.toDismissForOneMore(showing(30, 10, 50, 20), limit = 5))
    }

    @Test fun test_a_shade_already_over_the_limit_is_brought_back_under_it() {
        // Stories pushed for classifier matches are outside the background sync's own trimming, so more can be showing.
        val overflow = StoryNotificationLimit.toDismissForOneMore(showing(70, 10, 50, 20, 40, 30, 60), limit = 5)

        assertEquals(listOf("1:10", "1:20", "1:30"), overflow.map { it.storyHash })
    }
}
