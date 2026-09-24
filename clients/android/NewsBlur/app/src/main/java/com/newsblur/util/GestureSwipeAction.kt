package com.newsblur.util

import androidx.annotation.DrawableRes
import com.newsblur.R

/** GestureSwipeAction.kt resolves toggles to the destination shown by each swipe icon. */
data class GestureSwipeAction(
    val action: GestureAction,
    @DrawableRes val iconRes: Int,
) {
    companion object {
        @JvmStatic
        @JvmOverloads
        fun resolve(
            action: GestureAction,
            isRead: Boolean = false,
            isSaved: Boolean = false,
        ): GestureSwipeAction? {
            val destination =
                when (action) {
                    GestureAction.GEST_ACTION_TOGGLE_READ ->
                        if (isRead) GestureAction.GEST_ACTION_MARKUNREAD else GestureAction.GEST_ACTION_MARKREAD
                    GestureAction.GEST_ACTION_TOGGLE_SAVE ->
                        if (isSaved) GestureAction.GEST_ACTION_UNSAVE else GestureAction.GEST_ACTION_SAVE
                    else -> action
                }
            val icon =
                when (destination) {
                    GestureAction.GEST_ACTION_NONE -> return null
                    GestureAction.GEST_ACTION_BACK -> R.drawable.ic_arrow_back
                    GestureAction.GEST_ACTION_MARKREAD -> R.drawable.ic_indicator_read
                    GestureAction.GEST_ACTION_MARKUNREAD -> R.drawable.ic_indicator_unread
                    GestureAction.GEST_ACTION_SAVE -> R.drawable.ic_saved
                    GestureAction.GEST_ACTION_UNSAVE -> R.drawable.ic_unsaved
                    GestureAction.GEST_ACTION_STATISTICS -> R.drawable.ic_statistics
                    GestureAction.GEST_ACTION_MENU -> R.drawable.ic_more_vertical
                    GestureAction.GEST_ACTION_SHARE -> R.drawable.ic_share
                    GestureAction.GEST_ACTION_ASK_AI -> R.drawable.ic_ask_ai
                    GestureAction.GEST_ACTION_TRAIN -> R.drawable.ic_feed_train
                    GestureAction.GEST_ACTION_NOTIFICATIONS -> R.drawable.ic_notifications
                    GestureAction.GEST_ACTION_READ_RANGE -> R.drawable.ic_mark_read
                    GestureAction.GEST_ACTION_TOGGLE_READ, GestureAction.GEST_ACTION_TOGGLE_SAVE ->
                        error("GestureSwipeAction.kt must resolve toggles before choosing an icon")
                }
            return GestureSwipeAction(destination, icon)
        }
    }
}
