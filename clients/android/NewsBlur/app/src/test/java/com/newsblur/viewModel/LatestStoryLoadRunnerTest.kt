package com.newsblur.viewModel

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class LatestStoryLoadRunnerTest {
    @Test
    fun refreshBurstReadsOnlyTheLastRequestedSnapshot() = runTest {
        val queries = mutableListOf<Int>()
        val delivered = mutableListOf<Int>()
        val runner = LatestStoryLoadRunner(backgroundScope, StandardTestDispatcher(testScheduler), { request: Int ->
            queries.add(request)
            request
        }, {}, delivered::add) { throw it }

        repeat(100) { runner.submit(it) }
        runCurrent()

        assertEquals(listOf(99), queries)
        assertEquals(listOf(99), delivered)
        runner.close()
    }

    @Test
    fun replacementCancelsTheDatabaseSignalBeforeStartingAnotherQuery() = runTest {
        val events = mutableListOf<String>()
        val runner = LatestStoryLoadRunner<Int, Int>(backgroundScope, StandardTestDispatcher(testScheduler), { request ->
            events.add("query $request")
            awaitCancellation()
        }, { events.add("cancel $it") }, {}) { throw it }

        runner.submit(1)
        runCurrent()
        runner.submit(2)
        assertEquals(listOf("query 1", "cancel 1"), events)
        runCurrent()
        assertEquals(listOf("query 1", "cancel 1", "query 2"), events)
        runner.close()
    }

    @Test
    fun aSlowSupersededQueryCannotOverlapTheNextQueryOrPublishOldStories() = runTest {
        val releaseFirstQuery = CompletableDeferred<Unit>()
        val delivered = mutableListOf<Int>()
        val queries = mutableListOf<Int>()
        var activeQueries = 0
        var maximumQueries = 0
        val runner = LatestStoryLoadRunner(backgroundScope, StandardTestDispatcher(testScheduler), { request: Int ->
            activeQueries++
            maximumQueries = maxOf(maximumQueries, activeQueries)
            queries.add(request)
            try {
                if (request == 1) withContext(NonCancellable) { releaseFirstQuery.await() }
                request
            } finally {
                activeQueries--
            }
        }, {}, delivered::add) { throw it }

        runner.submit(1)
        runCurrent()
        runner.submit(2)
        runner.submit(3)
        runCurrent()
        assertEquals(listOf(1), queries)
        releaseFirstQuery.complete(Unit)
        runCurrent()

        assertEquals(1, maximumQueries)
        assertEquals(listOf(3), delivered)
        runner.close()
    }

    @Test
    fun clearingTheViewModelCancelsTheCurrentQueryAndDiscardsPendingWork() = runTest {
        val cancelled = mutableListOf<Int>()
        val delivered = mutableListOf<Int>()
        val runner = LatestStoryLoadRunner(backgroundScope, StandardTestDispatcher(testScheduler), { request: Int ->
            request
        }, cancelled::add, delivered::add) { throw it }

        runner.submit(1)
        runner.close()
        runCurrent()

        assertEquals(listOf(1), cancelled)
        assertTrue(delivered.isEmpty())
    }
}
