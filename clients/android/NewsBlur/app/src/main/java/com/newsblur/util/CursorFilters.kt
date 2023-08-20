package com.newsblur.util

import android.content.Context

data class CursorFilters(
        val stateFilter: StateFilter,
        val readFilter: ReadFilter,
        val storyOrder: StoryOrder,
) {

    constructor(context: Context, fs: FeedSet) : this(
            stateFilter = PrefsUtils.getStateFilter(context),
            readFilter = PrefsUtils.getReadFilter(context, fs),
            storyOrder = PrefsUtils.getStoryOrder(context, fs),
    )
}