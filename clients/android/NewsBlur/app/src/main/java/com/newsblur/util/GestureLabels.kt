package com.newsblur.util

import android.content.Context
import com.newsblur.R

/** GestureLabels.kt keeps the chooser and the visible swipe action in agreement. */
object GestureLabels {
    @JvmStatic fun title(
        context: Context,
        action: GestureAction,
    ): String =
        context.getString(
            when (action) {
                GestureAction.GEST_ACTION_NONE -> R.string.gesture_none
                GestureAction.GEST_ACTION_BACK -> R.string.gesture_back
                GestureAction.GEST_ACTION_TOGGLE_READ -> R.string.gesture_toggle_read
                GestureAction.GEST_ACTION_MARKREAD -> R.string.gesture_markread
                GestureAction.GEST_ACTION_MARKUNREAD -> R.string.gesture_markunread
                GestureAction.GEST_ACTION_SAVE -> R.string.gesture_save
                GestureAction.GEST_ACTION_UNSAVE -> R.string.gesture_unsave
                GestureAction.GEST_ACTION_STATISTICS -> R.string.gesture_statistics
                GestureAction.GEST_ACTION_MENU -> R.string.gesture_menu
                GestureAction.GEST_ACTION_SHARE -> R.string.gesture_share
                GestureAction.GEST_ACTION_TOGGLE_SAVE -> R.string.gesture_toggle_save
                GestureAction.GEST_ACTION_ASK_AI -> R.string.gesture_ask_ai
                GestureAction.GEST_ACTION_TRAIN -> R.string.gesture_train
                GestureAction.GEST_ACTION_NOTIFICATIONS -> R.string.gesture_notifications
                GestureAction.GEST_ACTION_READ_RANGE -> R.string.gesture_read_range
            },
        )
}
