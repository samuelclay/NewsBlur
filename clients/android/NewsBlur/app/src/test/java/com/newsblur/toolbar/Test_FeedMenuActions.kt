package com.newsblur.toolbar

import com.newsblur.R
import com.newsblur.delegate.FeedMenuPopover
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

@Suppress("ktlint:standard:class-naming")
class Test_FeedMenuActions {
    @Test fun test_feed_tools_share_one_group_and_destructive_actions_come_last() {
        val actions = FeedMenuPopover.actions
        assertEquals(actions.size, actions.map { it.id }.toSet().size)
        assertTrue(actions.all { it.icon != 0 })
        for (id in listOf(R.id.menu_statistics, R.id.menu_notifications, R.id.menu_intel, R.id.menu_discover_related_sites)) {
            assertEquals(2, actions.single { it.id == id }.group)
        }
        val firstDelete = actions.indexOfFirst { it.id == R.id.menu_delete_feed }
        assertTrue(actions.drop(firstDelete).all { it.group == 4 })
        assertTrue(actions.indexOfFirst { it.id == R.id.menu_instafetch_feed } < firstDelete)
    }
}
