package com.newsblur.util

import android.content.Context
import io.mockk.every
import io.mockk.mockk
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class Test_LogContext {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @After
    fun tear_down() {
        val context = mockk<Context>()
        every { context.externalCacheDir } returns null
        every { context.cacheDir } returns null
        Log.offerContext(context)
    }

    @Test
    fun test_external_storage_failure_falls_back_to_internal_log() {
        val context = mockk<Context>()
        every { context.externalCacheDir } throws NullPointerException("Attempt to get length of null array")
        every { context.cacheDir } returns temporaryFolder.root

        Log.offerContext(context)

        assertEquals(temporaryFolder.root, Log.getLogfile().parentFile)
    }

    @Test
    fun test_unavailable_cache_directories_disable_file_logging() {
        val context = mockk<Context>()
        every { context.externalCacheDir } throws SecurityException("Isolated process")
        every { context.cacheDir } throws SecurityException("Isolated process")

        Log.offerContext(context)

        assertNull(Log.getLogfile())
    }
}
