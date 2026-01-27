package com.newsblur.viewModel

import android.os.CancellationSignal
import android.os.OperationCanceledException
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Classifier
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
class ReadingViewModel
    @Inject
    constructor(
        private val dbHelper: BlurDatabaseHelper,
    ) : ViewModel() {
        private val cancellationSignal = CancellationSignal()

        private val _activeStories = MutableLiveData<StoryBatch>()
        val activeStories: LiveData<StoryBatch> = _activeStories

        private val loadSeq = AtomicLong(0)

        fun loadStories(
            fs: FeedSet,
            cursorFilters: CursorFilters,
        ) {
            viewModelScope.launch(Dispatchers.IO) {
                val currentLoadId = loadSeq.incrementAndGet()
                try {
                    dbHelper.getActiveStoriesCursor(fs, cursorFilters, cancellationSignal).use { c ->
                        val stories = mutableListOf<Story>()
                        val feedIds = mutableSetOf<String>()
                        var indexOfLastUnread = -1
                        if (c.moveToFirst()) {
                            var pos = 0
                            do {
                                val s = Story.fromCursor(c)
                                s.bindExternValues(c)
                                stories.add(s)
                                feedIds.add(s.feedId)
                                if (indexOfLastUnread == -1 && !s.read) indexOfLastUnread = pos
                                pos++
                            } while (c.moveToNext())
                        }

                        val classifiers = feedIds.associateWith { id -> dbHelper.getClassifierForFeed(id) }

                        _activeStories.postValue(
                            StoryBatch(
                                stories = stories,
                                indexOfLastUnread = indexOfLastUnread,
                                loadId = currentLoadId,
                                classifiers = classifiers,
                            ),
                        )
                    }
                } catch (e: OperationCanceledException) {
                    Log.d(this.javaClass.name, "Load canceled.")
                } catch (e: Exception) {
                    Log.e(this.javaClass.name, "Caught ${e.javaClass.name} in loadActiveStories.", e)
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
            val classifiers: Map<String, Classifier>,
        )
    }
