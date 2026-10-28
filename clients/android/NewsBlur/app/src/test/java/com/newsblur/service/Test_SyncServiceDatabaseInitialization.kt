package com.newsblur.service

import com.newsblur.database.BlurDatabaseHelper
import dagger.internal.Provider
import io.mockk.every
import io.mockk.mockk
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

class Test_SyncServiceDatabaseInitialization {
    @Test
    fun test_service_injection_defers_database_open_until_background_work() {
        val service = mockk<SyncService>(relaxed = true)
        every { service.dbHelper } answers { callOriginal() }
        every { service.dbHelperLazy } answers { callOriginal() }
        val database = mockk<BlurDatabaseHelper>()
        val initializationThreads = mutableListOf<Thread>()
        val provider = Provider {
            initializationThreads.add(Thread.currentThread())
            database
        }
        // SyncService.kt is injected on Android's main thread while NbApplication.kt warms the DB.
        SyncService_MembersInjector.create(
            Provider { mockk() }, Provider { mockk() }, Provider { mockk() },
            Provider { mockk() }, Provider { mockk() }, provider,
            Provider { mockk() }, Provider { mockk() }, Provider { mockk() },
            Provider { mockk() }, Provider { mockk() }, Provider { mockk() }
        ).injectMembers(service)

        assertEquals("Service injection must not wait on database disk IO", 0, initializationThreads.size)
        val worker = Executors.newSingleThreadExecutor()
        try {
            val backgroundThread = worker.submit<Thread> {
                assertSame(database, service.dbHelper)
                assertSame(database, service.dbHelper)
                Thread.currentThread()
            }.get(5, TimeUnit.SECONDS)
            assertEquals(listOf(backgroundThread), initializationThreads)
        } finally {
            worker.shutdownNow()
        }
    }
}
