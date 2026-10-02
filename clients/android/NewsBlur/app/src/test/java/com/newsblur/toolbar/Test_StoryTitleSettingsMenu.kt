package com.newsblur.toolbar

import android.view.Menu
import android.view.MenuItem
import android.view.SubMenu
import com.newsblur.R
import com.newsblur.delegate.ItemListMenuPopup
import com.newsblur.delegate.StoryTitleSettingsMenu
import com.newsblur.util.MarkStoryReadBehavior
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertTrue
import org.junit.Assert.assertEquals
import io.mockk.verify
import org.junit.Test

class Test_StoryTitleSettingsMenu {
    @Test fun test_global_story_settings_remain_available_without_feed_actions() {
        val menu = mockk<Menu>()
        every { menu.findItem(any()) } returns null
        every { menu.findItem(R.id.menu_theme) } returns mockk { every { isVisible } returns true }
        every { menu.findItem(R.id.menu_text_size) } returns mockk { every { isVisible } returns true }
        assertTrue("Story-title settings must expose theme and font size even without feed-specific actions", ItemListMenuPopup.hasVisibleActions(menu))
    }
    @Test fun test_all_site_stories_has_shared_controls_without_feed_only_actions() {
        val menu = mockk<Menu>()
        val expected = listOf(R.id.menu_mark_all_as_read, R.id.menu_mark_story_read, R.id.menu_text_size, R.id.menu_theme)
        every { menu.findItem(any()) } answers {
            if (firstArg<Int>() in expected) mockk { every { isVisible } returns true } else null
        }
        assertEquals(expected, StoryTitleSettingsMenu.actions.filter { menu.findItem(it.id)?.isVisible == true }.map { it.id })
        assertTrue(StoryTitleSettingsMenu.actions.all { it.icon != 0 })
    }

    @Test fun test_read_mode_submenu_preserves_selection_and_legacy_timing_without_extra_modes() {
        for (selected in MarkStoryReadBehavior.entries) {
            val menu = mockk<Menu>(relaxed = true)
            val submenu = mockk<SubMenu>(relaxed = true)
            val rows = mutableListOf<Pair<Int, MenuItem>>()
            every { menu.addSubMenu(any(), R.id.menu_mark_story_read, any(), any<Int>()) } returns submenu
            every { submenu.add(any(), any(), any(), any<Int>()) } answers {
                mockk<MenuItem>(relaxed = true).also { rows.add(secondArg<Int>() to it) }
            }
            StoryTitleSettingsMenu.prepareReadModes(menu, selected)
            assertEquals(MarkStoryReadBehavior.options(selected), rows.map { StoryTitleSettingsMenu.behaviorForItem(it.first) })
            rows.forEach { (id, item) ->
                verify { item.isCheckable = true }
                verify { item.isChecked = (StoryTitleSettingsMenu.behaviorForItem(id) == selected) }
            }
        }
    }

}
