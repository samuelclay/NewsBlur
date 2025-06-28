package com.newsblur.util

import com.newsblur.preference.PrefRepository

data class CursorFilters(
        val stateFilter: StateFilter,
        val readFilter: ReadFilter,
        val storyOrder: StoryOrder,
) {

    constructor(prefRepository: PrefRepository, fs: FeedSet) : this(
            stateFilter = prefRepository.getStateFilter(),
            readFilter = prefRepository.getReadFilter(fs),
            storyOrder = prefRepository.getStoryOrder(fs),
    )
}