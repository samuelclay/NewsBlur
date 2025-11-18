package com.newsblur.viewModel

import android.os.CancellationSignal
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Story
import com.newsblur.util.CursorFilters
import com.newsblur.util.FeedSet
import com.newsblur.util.Log
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicLong
import javax.inject.Inject

@HiltViewModel
class StoriesViewModel
    @Inject
    constructor(
        private val dbHelper: BlurDatabaseHelper,
    ) : ViewModel() {
        private val cancellationSignal = CancellationSignal()

        private val _activeStories = MutableLiveData<StoryBatch>()
        val activeStories: LiveData<StoryBatch> = _activeStories

        private val loadSeq = AtomicLong(0)

        fun loadActiveStories(
            fs: FeedSet,
            cursorFilters: CursorFilters,
        ) {
            viewModelScope.launch(Dispatchers.IO) {
                val currentLoadId = loadSeq.incrementAndGet()
                try {
                    dbHelper.getActiveStoriesCursor(fs, cursorFilters, cancellationSignal).use { cursor ->
                        val stories = mutableListOf<Story>()
                        var indexOfLastUnread = -1
                        if (cursor.moveToFirst()) {
                            var pos = 0
                            do {
                                val s = Story.fromCursor(cursor)
                                s.bindExternValues(cursor)
                                stories.add(s)
                                if (!s.read) indexOfLastUnread = pos
                                pos++
                            } while (cursor.moveToNext())
                        }

                        val storyBatch = StoryBatch(stories = stories, indexOfLastUnread = indexOfLastUnread, loadId = currentLoadId)
                        _activeStories.postValue(storyBatch)
                    }
                } catch (e: Exception) {
                    Log.e(this.javaClass.name, "Caught ${e.javaClass.name} in loadActiveStories.")
                }
            }
        }

        override fun onCleared() {
            cancellationSignal.cancel()
            super.onCleared()
        }

        data class StoryBatch(
            val stories: List<Story>,
            val indexOfLastUnread: Int,
            val loadId: Long,
        )
    }
