package com.newsblur.util

import android.content.Context
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.util.concurrent.ExecutorService
import java.util.concurrent.TimeUnit
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class Test_LogContext {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun test_startup_defers_cache_directory_disk_access_to_log_worker() {
        val executorField = Log::class.java.getDeclaredField("executor").apply { isAccessible = true }
        val originalExecutor = executorField.get(null)
        val work = mutableListOf<Runnable>()
        val executor = mockk<ExecutorService>()
        every { executor.execute(any()) } answers { work.add(firstArg()); Unit }
        val context = mockk<Context>()
        every { context.externalCacheDir } returns temporaryFolder.root
        executorField.set(null, executor)
        try {
            Log.offerContext(context)
            verify(exactly = 0) { context.externalCacheDir }
            work.toList().forEach(Runnable::run)
            assertEquals(temporaryFolder.root, Log.getLogfile().parentFile)
        } finally {
            executorField.set(null, originalExecutor)
        }
    }

    @After
    fun tear_down() {
        val context = mockk<Context>()
        every { context.externalCacheDir } returns null
        every { context.cacheDir } returns null
        Log.offerContext(context)
        await_log_worker()
    }

    @Test
    fun test_external_storage_failure_falls_back_to_internal_log() {
        val context = mockk<Context>()
        every { context.externalCacheDir } throws NullPointerException("Attempt to get length of null array")
        every { context.cacheDir } returns temporaryFolder.root

        Log.offerContext(context)
        await_log_worker()

        assertEquals(temporaryFolder.root, Log.getLogfile().parentFile)
    }

    @Test
    fun test_unavailable_cache_directories_disable_file_logging() {
        val context = mockk<Context>()
        every { context.externalCacheDir } throws SecurityException("Isolated process")
        every { context.cacheDir } throws SecurityException("Isolated process")

        Log.offerContext(context)
        await_log_worker()

        assertNull(Log.getLogfile())
    }

    private fun await_log_worker() {
        val executor = Log::class.java.getDeclaredField("executor").apply { isAccessible = true }
            .get(null) as ExecutorService
        executor.submit {}.get(5, TimeUnit.SECONDS)
    }
}
