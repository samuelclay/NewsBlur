package com.newsblur.delegate

import android.view.Menu
import com.newsblur.R
import com.newsblur.util.MarkStoryReadBehavior

/** StoryTitleSettingsMenu.kt adds global reading controls without inventing actions for the current feed scope. */
object StoryTitleSettingsMenu {
    val actions = FeedMenuPopover.actions.filter { it.group < 4 } + listOf(
        FeedMenuPopover.Action(R.id.menu_mark_story_read, R.drawable.ic_mark_read, 4),
        FeedMenuPopover.Action(R.id.menu_text_size, R.drawable.ic_story_text_gray46, 4),
        FeedMenuPopover.Action(R.id.menu_theme, R.drawable.ic_theme_dot_light, 4),
    ) + FeedMenuPopover.actions.filter { it.group == 4 }.map { it.copy(group = 5) }

    private val readModes = linkedMapOf(
        R.id.menu_mark_story_read_scroll to MarkStoryReadBehavior.ON_SCROLL,
        R.id.menu_mark_story_read_selection to MarkStoryReadBehavior.IMMEDIATELY,
        R.id.menu_mark_story_read_after_1 to MarkStoryReadBehavior.SECONDS_1,
        R.id.menu_mark_story_read_after_2 to MarkStoryReadBehavior.SECONDS_2,
        R.id.menu_mark_story_read_after_3 to MarkStoryReadBehavior.SECONDS_3,
        R.id.menu_mark_story_read_after_5 to MarkStoryReadBehavior.SECONDS_5,
        R.id.menu_mark_story_read_after_10 to MarkStoryReadBehavior.SECONDS_10,
        R.id.menu_mark_story_read_after_20 to MarkStoryReadBehavior.SECONDS_20,
        R.id.menu_mark_story_read_after_30 to MarkStoryReadBehavior.SECONDS_30,
        R.id.menu_mark_story_read_after_45 to MarkStoryReadBehavior.SECONDS_45,
        R.id.menu_mark_story_read_after_60 to MarkStoryReadBehavior.SECONDS_60,
        R.id.menu_mark_story_read_manually to MarkStoryReadBehavior.MANUALLY,
    )

    fun hasVisibleActions(menu: Menu): Boolean = actions.any { menu.findItem(it.id)?.isVisible == true }

    fun behaviorForItem(itemId: Int): MarkStoryReadBehavior? = readModes[itemId]

    fun prepareReadModes(menu: Menu, selected: MarkStoryReadBehavior) {
        menu.removeItem(R.id.menu_mark_story_read)
        val submenu = menu.addSubMenu(0, R.id.menu_mark_story_read, Menu.NONE, R.string.story_title_mark_story_read)
        MarkStoryReadBehavior.options(selected).forEachIndexed { index, behavior ->
            val id = readModes.entries.single { it.value == behavior }.key
            submenu.add(0, id, index, behavior.labelRes).apply {
                isCheckable = true
                isChecked = behavior == selected
            }
        }
    }
}
