package com.newsblur.delegate

import android.view.MenuItem
import android.view.View
import android.widget.PopupWindow
import androidx.appcompat.widget.PopupMenu
import com.newsblur.activity.NbActivity
import com.newsblur.domain.Story
import com.newsblur.util.FeedSet
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.StoryOrder
import com.newsblur.util.UIUtils

/** StoryMenuPopover.kt shares its presentation with feed and folder action menus. */
object StoryMenuPopover {
    fun show(
        activity: NbActivity,
        anchor: View,
        highlightedRow: View,
        feedSet: FeedSet,
        story: Story,
        order: StoryOrder,
        theme: ThemeValue,
        selected: (MenuItem) -> Boolean,
    ): PopupWindow {
        val model = PopupMenu(activity, anchor)
        UIUtils.inflateStoryContextMenu(model.menu, model.menuInflater, feedSet, story, order)
        return ActionMenuPopover.show(activity, anchor, highlightedRow, model.menu, theme, selected)
    }
}
