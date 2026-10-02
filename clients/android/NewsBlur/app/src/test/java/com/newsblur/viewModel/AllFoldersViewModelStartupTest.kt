package com.newsblur.viewModel

import android.database.Cursor
import android.os.CancellationSignal
import android.util.Log
import androidx.arch.core.executor.ArchTaskExecutor
import androidx.arch.core.executor.TaskExecutor
import androidx.lifecycle.viewModelScope
import com.newsblur.MainDispatcherRule
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.database.DatabaseConstants
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkStatic
import io.mockk.unmockkConstructor
import io.mockk.unmockkStatic
import io.mockk.verify
import kotlinx.coroutines.cancel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.assertSame
import org.junit.Before
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AllFoldersViewModelStartupTest {
    @get:Rule val mainDispatcher = MainDispatcherRule()

    @Before fun makeLiveDataSynchronous() {
        mockkConstructor(CancellationSignal::class)
        every { anyConstructed<CancellationSignal>().cancel() } returns Unit
        every { anyConstructed<CancellationSignal>().throwIfCanceled() } returns Unit
        mockkStatic(Log::class)
        every { Log.d(any(), any()) } returns 0
        every { Log.e(any(), any(), any()) } returns 0
        ArchTaskExecutor.getInstance().setDelegate(object : TaskExecutor() {
            override fun executeOnDiskIO(runnable: Runnable) = runnable.run()
            override fun postToMainThread(runnable: Runnable) = runnable.run()
            override fun isMainThread() = true
        })
    }

    @After fun restoreLiveDataExecutor() {
        ArchTaskExecutor.getInstance().setDelegate(null)
        unmockkConstructor(CancellationSignal::class)
        unmockkStatic(Log::class)
    }

    @Test fun emptyFoldersStillLoadFeedsAndCompleteTheFirstSnapshot() = runTest(mainDispatcher.dispatcher) {
        val db = emptyDatabase()
        val vm = AllFoldersViewModel(db, mainDispatcher.dispatcher)
        try {
            vm.getData()
            runCurrent()

            verify(exactly = 1) { db.getFeedsCursor(any()) }
            assertNotNull(vm.folders.value)
            assertNotNull(vm.feeds.value)
            assertEquals(0, vm.feeds.value!!.totalActiveFeedCount)
            assertEquals(emptyList<Any>(), vm.socialFeeds.value)
            assertNotNull(vm.savedStoryCounts.value)
            assertEquals(emptyList<Any>(), vm.savedSearch.value)
        } finally {
            vm.viewModelScope.cancel()
        }
    }

    @Test fun refreshBurstsQueryOneCachedSnapshotInsteadOfStartingParallelLoaders() = runTest(mainDispatcher.dispatcher) {
        val db = emptyDatabase()
        val vm = AllFoldersViewModel(db, mainDispatcher.dispatcher)
        try {
            repeat(20) { vm.getData() }
            runCurrent()

            verify(exactly = 1) { db.getFoldersCursor(any()) }
            verify(exactly = 1) { db.getFeedsCursor(any()) }
        } finally {
            vm.viewModelScope.cancel()
        }
    }

    @Test fun socialCountsDoNotPublishBeforeTheCachedFeedSnapshotIsReady() = runTest(mainDispatcher.dispatcher) {
        val db = emptyDatabase()
        val vm = AllFoldersViewModel(db, mainDispatcher.dispatcher)
        val seenFeedReadiness = mutableListOf<Boolean>()
        val observer = androidx.lifecycle.Observer<List<com.newsblur.domain.SocialFeed>> {
            seenFeedReadiness += vm.feeds.value != null && vm.folders.value != null
        }
        try {
            vm.socialFeeds.observeForever(observer)
            vm.getData()
            runCurrent()

            assertTrue("The initial empty snapshot must publish, including social feeds", seenFeedReadiness.isNotEmpty())
            assertTrue("AllFoldersViewModel.kt must not publish social-only startup counts", seenFeedReadiness.all { it })
        } finally {
            vm.socialFeeds.removeObserver(observer)
            vm.viewModelScope.cancel()
        }
    }

    @Test fun cachedFeedsStayVisibleDuringRefreshAndKeepActiveFeedTotals() = runTest(mainDispatcher.dispatcher) {
        val db = emptyDatabase()
        every { db.getFeedsCursor(any()) } answers { populatedFeedCursor() }
        val vm = AllFoldersViewModel(db, mainDispatcher.dispatcher)
        try {
            vm.getData()
            runCurrent()
            val first = vm.feeds.value!!
            assertEquals(listOf("1", "2"), first.feeds.keys.toList())
            assertEquals(1, first.totalActiveFeedCount)
            assertEquals(12, first.totalNeutCount)
            assertEquals(3, first.totalPosCount)

            vm.getData()
            assertSame("AllFoldersViewModel.kt keeps the usable cached snapshot during refresh", first, vm.feeds.value)
            runCurrent()
            assertEquals(12, vm.feeds.value!!.totalNeutCount)
        } finally {
            vm.viewModelScope.cancel()
        }
    }

    @Test fun aFailedRefreshKeepsThePreviousCompletedSnapshot() = runTest(mainDispatcher.dispatcher) {
        val db = emptyDatabase()
        val vm = AllFoldersViewModel(db, mainDispatcher.dispatcher)
        try {
            vm.getData()
            runCurrent()
            val first = vm.feeds.value!!
            every { db.getFeedsCursor(any()) } throws IllegalStateException("cache temporarily unavailable")

            vm.getData()
            runCurrent()

            assertSame(first, vm.feeds.value)
        } finally {
            vm.viewModelScope.cancel()
        }
    }

    private fun populatedFeedCursor(): Cursor {
        val rows = listOf(
            mapOf(DatabaseConstants.FEED_ID to "1", DatabaseConstants.FEED_ACTIVE to "1", DatabaseConstants.FEED_NEUTRAL_COUNT to "12", DatabaseConstants.FEED_POSITIVE_COUNT to "3"),
            mapOf(DatabaseConstants.FEED_ID to "2", DatabaseConstants.FEED_ACTIVE to "0", DatabaseConstants.FEED_NEUTRAL_COUNT to "100", DatabaseConstants.FEED_POSITIVE_COUNT to "100"),
        )
        var position = -1
        val columns = mutableListOf<String>()
        return mockk<Cursor>(relaxed = true).also { cursor ->
            every { cursor.count } returns rows.size
            every { cursor.isBeforeFirst } answers { position == -1 }
            every { cursor.moveToNext() } answers { ++position < rows.size }
            every { cursor.getColumnIndex(any()) } answers {
                val column = firstArg<String>()
                if (column !in columns) columns += column
                columns.indexOf(column)
            }
            every { cursor.getString(any()) } answers { rows[position][columns[firstArg()]] ?: "" }
            every { cursor.getInt(any()) } answers { rows[position][columns[firstArg()]]?.toIntOrNull() ?: 0 }
        }
    }

    private fun emptyDatabase(): BlurDatabaseHelper {
        val db = mockk<BlurDatabaseHelper>()
        fun cursor() = mockk<Cursor>(relaxed = true).also {
            every { it.count } returns 0
            every { it.isBeforeFirst } returns false
            every { it.moveToNext() } returns false
        }
        every { db.getFoldersCursor(any()) } answers { cursor() }
        every { db.getFeedsCursor(any()) } answers { cursor() }
        every { db.getSocialFeedsCursor(any()) } answers { cursor() }
        every { db.getSavedStoryCountsCursor(any()) } answers { cursor() }
        every { db.getSavedSearchCursor(any()) } answers { cursor() }
        return db
    }
}
