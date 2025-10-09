package com.newsblur.util

import com.newsblur.preference.PrefsRepo

data class CursorFilters(
    val stateFilter: StateFilter,
    val readFilter: ReadFilter,
    val storyOrder: StoryOrder,
) {
    constructor(prefsRepo: PrefsRepo, fs: FeedSet) : this(
        stateFilter = prefsRepo.getStateFilter(),
        readFilter = prefsRepo.getReadFilter(fs),
        storyOrder = prefsRepo.getStoryOrder(fs),
    )
}
