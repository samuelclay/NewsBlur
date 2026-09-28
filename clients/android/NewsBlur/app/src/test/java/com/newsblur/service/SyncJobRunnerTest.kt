package com.newsblur.service

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class SyncJobRunnerTest {
    @Test
    fun canceledBlockingFetchMustFinishBeforeTheReplacementBegins() = checkBlockingRestart(blockInChild = false)

    @Test
    fun canceledGenerationsMustWaitForTheirBlockingPrefetchChildren() = checkBlockingRestart(blockInChild = true)

    private fun checkBlockingRestart(blockInChild: Boolean) =
        runBlocking {
            val dispatcher = Executors.newFixedThreadPool(3).asCoroutineDispatcher()
            val parent = SupervisorJob()
            val scope = CoroutineScope(parent + dispatcher)
            val runner = SyncJobRunner()
            val blocked = CountDownLatch(1)
            val release = CountDownLatch(1)
            val replacementStarted = CountDownLatch(1)
            val active = AtomicInteger()
            val peak = AtomicInteger()

            fun blockingFetch() {
                peak.accumulateAndGet(active.incrementAndGet(), ::maxOf)
                blocked.countDown()
                try {
                    check(release.await(5, TimeUnit.SECONDS))
                } finally {
                    active.decrementAndGet()
                }
            }
            try {
                val old =
                    runner.launchIn(scope) {
                        if (blockInChild) coroutineScope { launch { blockingFetch() } } else blockingFetch()
                    }
                assertTrue("The first fake network parse must be in flight", blocked.await(5, TimeUnit.SECONDS))
                old.cancel()
                val latest =
                    runner.launchIn(scope) {
                        peak.accumulateAndGet(active.incrementAndGet(), ::maxOf)
                        replacementStarted.countDown()
                        active.decrementAndGet()
                    }
                val overlapped = replacementStarted.await(300, TimeUnit.MILLISECONDS)
                release.countDown()
                withTimeout(5_000) {
                    old.join()
                    latest.join()
                }

                assertFalse("Cancellation does not interrupt blocking API/Gson work", overlapped)
                assertEquals("Only one sync generation may execute", 1, peak.get())
                assertEquals("The latest foreground request must still run", 0L, replacementStarted.count)
            } finally {
                release.countDown()
                parent.cancelAndJoin()
                dispatcher.close()
            }
        }

    @Test
    fun replacingAQueuedGenerationDoesNotLoseTheLatestRequest() =
        runBlocking {
            val dispatcher = Executors.newFixedThreadPool(3).asCoroutineDispatcher()
            val parent = SupervisorJob()
            val scope = CoroutineScope(parent + dispatcher)
            val runner = SyncJobRunner()
            val blocked = CountDownLatch(1)
            val release = CountDownLatch(1)
            val staleRuns = AtomicInteger()
            val latestRuns = AtomicInteger()
            try {
                val old =
                    runner.launchIn(scope) {
                        blocked.countDown()
                        check(release.await(5, TimeUnit.SECONDS))
                    }
                assertTrue(blocked.await(5, TimeUnit.SECONDS))
                old.cancel()
                val stale = runner.launchIn(scope) { staleRuns.incrementAndGet() }
                // SyncService.kt may receive another intent while the replacement is waiting.
                Thread.sleep(100)
                stale.cancel()
                val latest = runner.launchIn(scope) { latestRuns.incrementAndGet() }
                release.countDown()
                withTimeout(5_000) {
                    old.join()
                    stale.join()
                    latest.join()
                }

                assertEquals(0, staleRuns.get())
                assertEquals(1, latestRuns.get())
            } finally {
                release.countDown()
                parent.cancelAndJoin()
                dispatcher.close()
            }
        }

    @Test
    fun serviceShutdownCancelsQueuedWorkAndCompletesItsCallback() =
        runBlocking {
            val dispatcher = Executors.newFixedThreadPool(2).asCoroutineDispatcher()
            val parent = SupervisorJob()
            val scope = CoroutineScope(parent + dispatcher)
            val runner = SyncJobRunner()
            val blocked = CountDownLatch(1)
            val release = CountDownLatch(1)
            val pendingRuns = AtomicInteger()
            val completions = AtomicInteger()
            try {
                val running =
                    runner.launchIn(scope) {
                        blocked.countDown()
                        check(release.await(5, TimeUnit.SECONDS))
                    }
                assertTrue(blocked.await(5, TimeUnit.SECONDS))
                val pending = runner.launchIn(scope) { pendingRuns.incrementAndGet() }
                pending.invokeOnCompletion { completions.incrementAndGet() }
                parent.cancel()
                withTimeout(5_000) { pending.join() }

                assertEquals(0, pendingRuns.get())
                assertEquals(1, completions.get())
                assertFalse("Blocking cleanup still owns the execution permit", running.isCompleted)
            } finally {
                release.countDown()
                parent.cancelAndJoin()
                dispatcher.close()
            }
        }
}
