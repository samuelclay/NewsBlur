package com.newsblur.service

import com.newsblur.util.Log
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import io.mockk.verify
import kotlinx.coroutines.SupervisorJob
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class Test_SyncServiceShutdown {
    @After
    fun tear_down() {
        unmockkAll()
    }

    @Test
    fun test_shutdown_after_failed_injection_still_cancels_service_work() {
        val service = fixture()
        val job = SupervisorJob()
        every { service.coroutineContext } returns job

        destroy(service)

        assertTrue(job.isCancelled)
    }

    @Test
    fun test_stopping_a_job_after_failed_injection_does_not_access_missing_state() {
        val service = fixture()
        every { service.onStopJob(null) } answers { callOriginal() }

        assertFalse(service.onStopJob(null))
    }

    @Test
    fun test_shutdown_after_injection_returns_shared_state_to_idle() {
        val service = fixture()
        val state = mockk<SyncServiceState>(relaxed = true)
        service.syncServiceState = state
        every { service.coroutineContext } returns SupervisorJob()

        destroy(service)

        verify { state.setServiceState(ServiceState.Idle) }
    }

    private fun fixture(): SyncService {
        mockkStatic(Log::class)
        every { Log.d(any<Any>(), any()) } returns Unit
        val service = mockk<SyncService>(relaxed = true)
        every { service.syncServiceState } answers { callOriginal() }
        every { service.syncServiceState = any() } answers { callOriginal() }
        every { service.onDestroy() } answers { callOriginal() }
        return service
    }

    private fun destroy(service: SyncService) {
        try {
            service.onDestroy()
        } catch (exception: RuntimeException) {
            // SyncService.kt has completed its cleanup when the Android framework stub is reached.
            if (exception.message?.startsWith("Method onDestroy in android.app.Service not mocked") != true) throw exception
        }
    }
}
