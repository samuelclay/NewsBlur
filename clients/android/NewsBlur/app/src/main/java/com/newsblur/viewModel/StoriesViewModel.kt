package com.newsblur.viewModel

import android.os.CancellationSignal
import android.os.SystemClock
import androidx.annotation.MainThread
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.BuildConfig
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Story
import com.newsblur.util.CursorFilters
import com.newsblur.util.FeedSet
import com.newsblur.util.Log
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import java.util.concurrent.atomic.AtomicLong
import javax.inject.Inject

@HiltViewModel
class StoriesViewModel
    @Inject
    constructor(
        private val dbHelper: BlurDatabaseHelper,
    ) : ViewModel() {
        private val _activeStories = MutableLiveData<StoryBatch>()
        val activeStories: LiveData<StoryBatch> = _activeStories

        private val loadSeq = AtomicLong(0)
        private val loader =
            LatestStoryLoadRunner(
                scope = viewModelScope,
                queryDispatcher = Dispatchers.IO,
                load = ::readStories,
                cancel = { request: LoadRequest ->
                    traceLoad("cancel", request)
                    request.cancellationSignal.cancel()
                },
                publish = { batch: StoryBatch ->
                    if (BuildConfig.DEBUG) android.util.Log.d("NB.StoryLoad", "publish id=${batch.loadId} rows=${batch.stories.size}")
                    _activeStories.value = batch
                },
                sameQuery = { first, second -> first.feedSet == second.feedSet && first.cursorFilters == second.cursorFilters },
                onError = { error -> Log.e(this.javaClass.name, "Caught ${error.javaClass.name} in loadActiveStories.", error) },
            )

        @MainThread
        fun loadActiveStories(
            fs: FeedSet,
            cursorFilters: CursorFilters,
        ) {
            loader.submit(
                LoadRequest(
                    feedSet = FeedSet.fromCompactSerial(fs.toCompactSerial()),
                    cursorFilters = cursorFilters,
                    cancellationSignal = CancellationSignal(),
                    loadId = loadSeq.incrementAndGet(),
                ),
            )
        }

        private suspend fun readStories(request: LoadRequest): StoryBatch {
            if (BuildConfig.DEBUG) request.startedAtMillis = SystemClock.elapsedRealtime()
            traceLoad("start", request)
            // BlurDatabaseHelper.java's shared session may still belong to the previous feed.
            // ItemSetFragment.java already handles this empty/not-ready result by requesting that feed's session.
            if (!dbHelper.isFeedSetReady(request.feedSet)) {
                traceLoad("not_ready", request)
                return StoryBatch(request.feedSet, emptyList(), -1, request.loadId)
            }
            val context = currentCoroutineContext()
            return dbHelper.getActiveStoriesCursor(request.feedSet, request.cursorFilters, request.cancellationSignal).use { cursor ->
                val stories = mutableListOf<Story>()
                var indexOfLastUnread = -1
                if (cursor.moveToFirst()) {
                    do {
                        context.ensureActive()
                        request.cancellationSignal.throwIfCanceled()
                        val story = Story.fromCursor(cursor)
                        story.bindExternValues(cursor)
                        stories.add(story)
                        if (BuildConfig.DEBUG) request.parsedCount = stories.size
                        if (!story.read) indexOfLastUnread = stories.lastIndex
                    } while (cursor.moveToNext())
                }
                context.ensureActive()
                traceLoad("end", request)
                StoryBatch(request.feedSet, stories, indexOfLastUnread, request.loadId)
            }
        }

        private fun traceLoad(event: String, request: LoadRequest) {
            if (!BuildConfig.DEBUG) return
            val elapsed = if (request.startedAtMillis == 0L) 0L else SystemClock.elapsedRealtime() - request.startedAtMillis
            android.util.Log.d("NB.StoryLoad", "$event id=${request.loadId} rows=${request.parsedCount} elapsedMs=$elapsed")
        }

        override fun onCleared() {
            loader.close()
            super.onCleared()
        }

        private data class LoadRequest(
            val feedSet: FeedSet,
            val cursorFilters: CursorFilters,
            val cancellationSignal: CancellationSignal,
            val loadId: Long,
        ) {
            @Volatile var startedAtMillis = 0L
            @Volatile var parsedCount = 0
        }

        data class StoryBatch(
            val feedSet: FeedSet,
            val stories: List<Story>,
            val indexOfLastUnread: Int,
            val loadId: Long,
        )
    }
