package com.newsblur.viewModel

import android.database.Cursor
import android.os.CancellationSignal
import androidx.arch.core.executor.ArchTaskExecutor
import androidx.arch.core.executor.TaskExecutor
import androidx.lifecycle.viewModelScope
import com.newsblur.MainDispatcherRule
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Story
import com.newsblur.util.CursorFilters
import com.newsblur.util.FeedSet
import com.newsblur.util.ReadFilter
import com.newsblur.util.StateFilter
import com.newsblur.util.StoryOrder
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkStatic
import io.mockk.unmockkConstructor
import io.mockk.unmockkStatic
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class Test_ReadingRefresh {
    @get:Rule val main = MainDispatcherRule()

    @Test
    fun test_refresh_burst_reads_only_the_latest_session_and_keeps_its_order() = runTest(main.dispatcher) {
        val db = mockk<BlurDatabaseHelper>(relaxed = true)
        val filters = CursorFilters(StateFilter.ALL, ReadFilter.ALL, StoryOrder.NEWEST)
        val queried = mutableListOf<String>()
        val rows = listOf("already-read", "unread", "next-unread")
        mockkConstructor(CancellationSignal::class)
        mockkStatic(Story::class)
        ArchTaskExecutor.getInstance().setDelegate(object : TaskExecutor() {
            override fun executeOnDiskIO(runnable: Runnable) = runnable.run()
            override fun postToMainThread(runnable: Runnable) = runnable.run()
            override fun isMainThread() = true
        })
        val reader = ReadingViewModel(db, main.dispatcher)
        try {
            every { anyConstructed<CancellationSignal>().cancel() } returns Unit
            every { db.getReadingStoriesCursor(any(), any(), any()) } answers {
                val feedId = firstArg<FeedSet>().singleFeed
                queried.add(feedId)
                var position = 0
                mockk<Cursor>(relaxed = true).also { cursor ->
                    every { cursor.moveToFirst() } returns true
                    every { cursor.moveToNext() } answers { ++position < rows.size }
                    every { Story.fromCursor(cursor) } answers {
                        Story().also { story ->
                            story.storyHash = rows[position]
                            story.read = position == 0
                            story.feedId = feedId
                        }
                    }
                }
            }

            repeat(8) { reader.loadStories(FeedSet.singleFeed("old"), filters) }
            reader.loadStories(FeedSet.singleFeed("new"), filters)
            runCurrent()

            assertEquals(listOf("new"), queried)
            val batch = requireNotNull(reader.activeStories.value)
            assertEquals(rows, batch.stories.map { it.storyHash })
            assertEquals(1, batch.indexOfLastUnread)
        } finally {
            reader.viewModelScope.cancel()
            ArchTaskExecutor.getInstance().setDelegate(null)
            unmockkStatic(Story::class)
            unmockkConstructor(CancellationSignal::class)
        }
    }
}
