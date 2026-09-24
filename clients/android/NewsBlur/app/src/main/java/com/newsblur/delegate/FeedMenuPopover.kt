package com.newsblur.delegate

import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.widget.PopupWindow
import androidx.appcompat.widget.PopupMenu
import com.newsblur.R
import com.newsblur.activity.NbActivity
import com.newsblur.util.PrefConstants.ThemeValue

/** FeedMenuPopover.kt keeps feed-list and story-list actions in the same order and visual groups. */
object FeedMenuPopover {
    data class Action(val id: Int, val icon: Int, val group: Int)

    val actions = listOf(
        Action(R.id.menu_mark_feed_as_read, R.drawable.ic_mark_read, 1),
        Action(R.id.menu_mark_folder_as_read, R.drawable.ic_mark_read, 1),
        Action(R.id.menu_mark_all_as_read, R.drawable.ic_mark_read, 1),
        Action(R.id.menu_instafetch_feed, R.drawable.ic_cloud_download, 1),
        Action(R.id.menu_statistics, R.drawable.ic_burst, 2),
        Action(R.id.menu_notifications, R.drawable.nb_menu_notifications, 2),
        Action(R.id.menu_intel, R.drawable.ic_feed_train, 2),
        Action(R.id.menu_discover_related_sites, R.drawable.ic_discover, 2),
        Action(R.id.menu_choose_folders, R.drawable.ic_folder, 3),
        Action(R.id.menu_rename_feed, R.drawable.ic_file_edit, 3),
        Action(R.id.menu_rename_folder, R.drawable.ic_file_edit, 3),
        Action(R.id.menu_mute_feed, R.drawable.mute_black, 3),
        Action(R.id.menu_unmute_feed, R.drawable.mute_black, 3),
        Action(R.id.menu_mute_folder, R.drawable.mute_black, 3),
        Action(R.id.menu_unmute_folder, R.drawable.mute_black, 3),
        Action(R.id.menu_infrequent_cutoff, R.drawable.ic_calendar, 3),
        Action(R.id.menu_save_search, R.drawable.ic_search, 3),
        Action(R.id.menu_delete_feed, R.drawable.ic_clear, 4),
        Action(R.id.menu_delete_folder, R.drawable.ic_clear, 4),
        Action(R.id.menu_unfollow, R.drawable.ic_clear, 4),
        Action(R.id.menu_delete_saved_search, R.drawable.ic_clear, 4),
    )

    @JvmStatic fun hasVisibleActions(menu: Menu) = actions.any { menu.findItem(it.id)?.isVisible == true }

    @JvmStatic fun show(
        activity: NbActivity,
        anchor: View,
        source: Menu,
        theme: ThemeValue,
        selected: MenuItem.OnMenuItemClickListener,
    ): PopupWindow {
        return showWithActions(activity, anchor, source, theme, actions, selected)
    }

    fun showWithActions(
        activity: NbActivity,
        anchor: View,
        source: Menu,
        theme: ThemeValue,
        configuredActions: List<Action>,
        selected: MenuItem.OnMenuItemClickListener,
    ): PopupWindow {
        val menu = PopupMenu(activity, anchor).menu
        configuredActions.forEachIndexed { index, action ->
            val item = source.findItem(action.id)?.takeIf { it.isVisible } ?: return@forEachIndexed
            val submenu = item.subMenu
            val copy = if (submenu == null) {
                menu.add(action.group, item.itemId, index, item.title)
            } else {
                val target = menu.addSubMenu(action.group, item.itemId, index, item.title)
                for (childIndex in 0 until submenu.size()) {
                    val child = submenu.getItem(childIndex)
                    if (!child.isVisible) continue
                    target.add(0, child.itemId, childIndex, child.title).apply {
                        isCheckable = child.isCheckable
                        isChecked = child.isChecked
                        isEnabled = child.isEnabled
                        setIcon(when (child.itemId) {
                            R.id.menu_notifications_focus -> R.drawable.ic_indicator_focus
                            R.id.menu_notifications_unread -> R.drawable.ic_indicator_unread
                            R.id.menu_notifications_disable -> R.drawable.mute_black
                            else -> action.icon
                        })
                    }
                }
                target.item
            }
            copy.setIcon(action.icon)
            copy.isEnabled = item.isEnabled
        }
        return ActionMenuPopover.show(activity, anchor, menu, theme, selected)
    }
}
