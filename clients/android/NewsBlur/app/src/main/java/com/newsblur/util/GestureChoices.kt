package com.newsblur.util

/** GestureChoices.kt supplies the story long-press choices shown by SettingsScreen.kt. */
object GestureChoices {
    val storyLongPress = listOf(
        GestureAction.GEST_ACTION_ASK_AI,
        GestureAction.GEST_ACTION_SHARE,
        GestureAction.GEST_ACTION_MARKUNREAD,
        GestureAction.GEST_ACTION_TOGGLE_SAVE,
        GestureAction.GEST_ACTION_SAVE,
        GestureAction.GEST_ACTION_TRAIN,
        GestureAction.GEST_ACTION_MENU,
        GestureAction.GEST_ACTION_NONE,
    )
}
