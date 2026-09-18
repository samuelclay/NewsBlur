package com.newsblur.util

/** StoryLoadingState.kt distinguishes initial loading, pagination, and terminal/offline states. */
enum class StoryLoadingState {
    NONE, INITIAL, NEXT_PAGE;

    companion object {
        @JvmStatic fun resolve(hasStories: Boolean, dataSeen: Boolean, syncing: Boolean, exhausted: Boolean, online: Boolean): StoryLoadingState {
            if (!online || exhausted) return NONE
            if (!hasStories) return INITIAL
            return if (!dataSeen || syncing) NEXT_PAGE else NONE
        }
    }
}
