package com.newsblur.viewModel

import android.os.CancellationSignal
import androidx.annotation.MainThread
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
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import javax.inject.Inject

@HiltViewModel
class ReadingViewModel
    internal constructor(
        private val dbHelper: BlurDatabaseHelper,
        private val queryDispatcher: CoroutineDispatcher,
    ) : ViewModel() {
        @Inject
        constructor(dbHelper: BlurDatabaseHelper) : this(dbHelper, Dispatchers.IO)

        private val _activeStories = MutableLiveData<StoryBatch>()
        val activeStories: LiveData<StoryBatch> = _activeStories

        private var loadSeq = 0L
        private var preparedSavedSession = -1L
        private val loader =
            LatestStoryLoadRunner(
                scope = viewModelScope,
                queryDispatcher = queryDispatcher,
                load = ::readStories,
                cancel = { request: LoadRequest -> request.signal.cancel() },
                publish = { batch: StoryBatch -> _activeStories.value = batch },
                sameQuery = { first, second -> first.feedSet == second.feedSet && first.filters == second.filters },
                onError = { error -> Log.e(javaClass.name, "Caught ${error.javaClass.name} in loadActiveStories.", error) },
            )

        @MainThread
        fun loadStories(
            fs: FeedSet,
            cursorFilters: CursorFilters,
            restoringReader: Boolean = false,
        ) {
            loader.submit(
                LoadRequest(
                    feedSet = FeedSet.fromCompactSerial(fs.toCompactSerial()),
                    filters = cursorFilters,
                    restoringReader = restoringReader,
                    signal = CancellationSignal(),
                    loadId = ++loadSeq,
                ),
            )
        }

        private suspend fun readStories(request: LoadRequest): StoryBatch {
            val context = currentCoroutineContext()
            val stories = mutableListOf<Story>()
            val feedIds = mutableSetOf<String>()
            var indexOfLastUnread = -1
            preparedSavedSession = dbHelper.prepareSavedReadingSession(request.feedSet, preparedSavedSession, request.restoringReader)
            dbHelper.getReadingStoriesCursor(request.feedSet, request.filters, request.signal).use { cursor ->
                if (cursor.moveToFirst()) {
                    do {
                        context.ensureActive()
                        val story = Story.fromCursor(cursor)
                        story.bindExternValues(cursor)
                        stories.add(story)
                        feedIds.add(story.feedId)
                        if (indexOfLastUnread == -1 && !story.read) indexOfLastUnread = stories.lastIndex
                    } while (cursor.moveToNext())
                }
            }
            val classifiers = feedIds.associateWith { feedId ->
                context.ensureActive()
                dbHelper.getClassifierForFeed(feedId)
            }
            return StoryBatch(stories, indexOfLastUnread, request.loadId, classifiers)
        }

        override fun onCleared() {
            loader.close()
            super.onCleared()
        }

        private data class LoadRequest(
            val feedSet: FeedSet,
            val filters: CursorFilters,
            val restoringReader: Boolean,
            val signal: CancellationSignal,
            val loadId: Long,
        )

        data class StoryBatch(
            val stories: List<Story>,
            val indexOfLastUnread: Int,
            val loadId: Long,
            val classifiers: Map<String, Classifier>,
        )
    }
