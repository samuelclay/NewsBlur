package com.newsblur.viewModel

import android.content.Context
import android.os.CancellationSignal
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.StarredCount
import com.newsblur.domain.Story
import com.newsblur.service.SyncServiceState
import com.newsblur.util.FeedUtils
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.Collections
import javax.inject.Inject

@HiltViewModel
class StoryUserTagsViewModel
    @Inject
    constructor(
        @param:ApplicationContext private val context: Context,
        private val dbHelper: BlurDatabaseHelper,
        private val syncServiceState: SyncServiceState,
        private val feedUtils: FeedUtils,
    ) : ViewModel() {
        private val cancellationSignal = CancellationSignal()
        private val _storyCounts = MutableStateFlow<List<StarredCount>>(emptyList())
        val storyCounts = _storyCounts.asStateFlow()

        init {
            getSavedStoryCounts()
        }

        private fun getSavedStoryCounts() {
            viewModelScope.launch(Dispatchers.IO) {
                dbHelper.getSavedStoryCountsCursor(cancellationSignal).use { cursor ->
                    if (!cursor.isBeforeFirst) return@use
                    val starredTags = mutableListOf<StarredCount>()
                    while (cursor.moveToNext()) {
                        val sc = StarredCount.fromCursor(cursor)
                        if (sc.tag != null && !sc.isTotalCount) {
                            starredTags.add(sc)
                        }
                    }
                    Collections.sort(starredTags, StarredCount.StarredCountComparatorByTag)
                    _storyCounts.emit(starredTags)
                }
            }
        }

        fun saveTags(
            story: Story,
            tags: List<String>,
        ) {
            syncServiceState.forceFeedsFolders()
            feedUtils.setStorySaved(story, true, context, story.highlights.toList(), tags)
        }

        override fun onCleared() {
            cancellationSignal.cancel()
            super.onCleared()
        }
    }
