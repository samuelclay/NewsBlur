package com.newsblur.util

import com.newsblur.util.StoryNotificationLimit.Showing
import org.junit.Assert.assertEquals
import org.junit.Test

class Test_StoryNotificationLimit {
    private fun story(time: Long) = Showing(id = time.toInt(), storyTime = time, storyHash = "1:$time")

    private fun showing(vararg storyTimes: Long) = storyTimes.map { story(it) }

    private fun dismissed(showing: List<Showing>, incoming: Long) =
        StoryNotificationLimit.toDismiss(showing, story(incoming), limit = 5).map { it.storyHash }

    @Test fun test_sixth_story_takes_the_place_of_the_oldest_one_showing() {
        // NotificationUtils.java shows five stories at most; a pushed sixth must not pile up in the shade.
        assertEquals(listOf("1:10"), dismissed(showing(30, 10, 50, 20, 40), incoming = 60))
    }

    @Test fun test_nothing_is_dismissed_while_there_is_room() {
        assertEquals(emptyList<String>(), dismissed(showing(30, 10, 50, 20), incoming = 60))
    }

    @Test fun test_a_shade_already_over_the_limit_is_brought_back_under_it() {
        // Stories pushed for classifier matches are outside the background sync's own trimming, so more can be showing.
        assertEquals(listOf("1:10", "1:20", "1:30"), dismissed(showing(70, 10, 50, 20, 40, 30, 60), incoming = 80))
    }

    @Test fun test_an_old_pushed_story_does_not_take_the_place_of_a_newer_one() {
        // A classifier match can be pushed for a story older than everything showing. It is the one left out.
        assertEquals(listOf("1:5"), dismissed(showing(30, 10, 50, 20, 40), incoming = 5))
    }
}
