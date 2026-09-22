package com.newsblur.service

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.ensureActive
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

class SyncRequestCoordinatorTest {
    @Test
    fun repeatedRequestsDoNotDiscardTheInflightFeedPage() = runBlocking {
        val dispatcher = Executors.newFixedThreadPool(3).asCoroutineDispatcher()
        val parent = SupervisorJob()
        val scope = CoroutineScope(parent + dispatcher)
        val coordinator = SyncRequestCoordinator(SyncJobRunner())
        val started = CountDownLatch(1)
        val release = CountDownLatch(1)
        val attempts = AtomicInteger()
        val inserted = AtomicInteger()
        val backgrounds = AtomicInteger()
        val foreground: suspend CoroutineScope.() -> Unit = {
            val attempt = attempts.incrementAndGet()
            if (attempt == 1) {
                started.countDown()
                check(release.await(5, TimeUnit.SECONDS))
            }
            // SyncService.kt checks cancellation before inserting a blocking API response.
            ensureActive()
            inserted.incrementAndGet()
        }
        val background: suspend CoroutineScope.() -> Unit = { backgrounds.incrementAndGet(); Unit }
        try {
            val first = coordinator.request(scope, foreground, background)
            assertTrue(started.await(5, TimeUnit.SECONDS))
            val requests = List(20) { coordinator.request(scope, foreground, background) }
            release.countDown()
            withTimeout(5_000) { first.join(); requests.forEach { it.join() } }

            assertEquals("The in-flight page and one coalesced followup must both commit", 2, inserted.get())
            assertEquals("A burst must produce only one followup pass", 2, attempts.get())
            assertEquals("Prefetch waits until foreground requests are caught up", 1, backgrounds.get())
        } finally {
            release.countDown()
            parent.cancelAndJoin()
            dispatcher.close()
        }
    }

    @Test
    fun foregroundRequestsInterruptBackgroundPrefetchWithoutOverlappingIt() = runBlocking {
        val dispatcher = Executors.newFixedThreadPool(3).asCoroutineDispatcher()
        val parent = SupervisorJob()
        val scope = CoroutineScope(parent + dispatcher)
        val coordinator = SyncRequestCoordinator(SyncJobRunner())
        val backgroundStarted = CountDownLatch(1)
        val release = CountDownLatch(1)
        val latestStarted = CountDownLatch(1)
        val foregroundRuns = AtomicInteger()
        val backgroundRuns = AtomicInteger()
        val foreground: suspend CoroutineScope.() -> Unit = {
            if (foregroundRuns.incrementAndGet() == 2) latestStarted.countDown()
        }
        val background: suspend CoroutineScope.() -> Unit = {
            if (backgroundRuns.incrementAndGet() == 1) {
                backgroundStarted.countDown()
                check(release.await(5, TimeUnit.SECONDS))
                awaitCancellation()
            }
        }
        try {
            val first = coordinator.request(scope, foreground, background)
            assertTrue(backgroundStarted.await(5, TimeUnit.SECONDS))
            val latest = coordinator.request(scope, foreground, background)
            assertFalse("Blocking prefetch must finish before another generation runs", latestStarted.await(100, TimeUnit.MILLISECONDS))
            release.countDown()
            withTimeout(5_000) { first.join(); latest.join() }
            assertEquals(2, foregroundRuns.get())
            assertEquals(2, backgroundRuns.get())
        } finally {
            release.countDown()
            parent.cancelAndJoin()
            dispatcher.close()
        }
    }

    @Test
    fun serviceShutdownStillCancelsForegroundWorkAndPendingRequests() = runBlocking {
        val dispatcher = Executors.newFixedThreadPool(2).asCoroutineDispatcher()
        val parent = SupervisorJob()
        val scope = CoroutineScope(parent + dispatcher)
        val coordinator = SyncRequestCoordinator(SyncJobRunner())
        val started = CountDownLatch(1)
        val release = CountDownLatch(1)
        val commits = AtomicInteger()
        val foreground: suspend CoroutineScope.() -> Unit = {
            started.countDown()
            check(release.await(5, TimeUnit.SECONDS))
            ensureActive()
            commits.incrementAndGet()
        }
        try {
            coordinator.request(scope, foreground, {})
            assertTrue(started.await(5, TimeUnit.SECONDS))
            coordinator.request(scope, foreground, {})
            parent.cancel()
            release.countDown()
            withTimeout(5_000) { parent.join() }
            assertEquals(0, commits.get())
        } finally {
            release.countDown()
            parent.cancelAndJoin()
            dispatcher.close()
        }
    }
}
