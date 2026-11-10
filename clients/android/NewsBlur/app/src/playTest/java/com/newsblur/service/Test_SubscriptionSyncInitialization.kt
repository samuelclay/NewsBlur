package com.newsblur.service

import com.android.billingclient.api.BillingClient
import com.newsblur.network.UserApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.Log
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class Test_SubscriptionSyncInitialization {
    @Test
    fun test_job_start_returns_while_billing_client_builds_off_main_thread() {
        val main = Executors.newSingleThreadExecutor().asCoroutineDispatcher()
        Dispatchers.setMain(main)
        mockkStatic(Log::class)
        every { Log.d(any<Any>(), any()) } returns Unit
        mockkStatic(BillingClient::class)
        val builder = mockk<BillingClient.Builder>()
        val client = mockk<BillingClient>()
        val building = CountDownLatch(1)
        val releaseBuild = CountDownLatch(1)
        val connected = CountDownLatch(1)
        val returned = CountDownLatch(1)
        val buildThread = AtomicReference<Thread>()
        val connectionThread = AtomicReference<Thread>()
        val mainThread = AtomicReference<Thread>()
        every { BillingClient.newBuilder(any()) } returns builder
        every { builder.setListener(any()) } returns builder
        every { builder.enablePendingPurchases(any()) } returns builder
        every { builder.build() } answers {
            buildThread.set(Thread.currentThread())
            building.countDown()
            check(releaseBuild.await(10, TimeUnit.SECONDS))
            client
        }
        every { client.startConnection(any()) } answers {
            connectionThread.set(Thread.currentThread())
            connected.countDown()
        }
        val service = mockk<SubscriptionSyncService>(relaxed = true)
        every { service.onStartJob(any()) } answers { callOriginal() }
        every { service.prefsRepo } answers { callOriginal() }
        every { service.userApi } answers { callOriginal() }
        every { service.syncServiceState } answers { callOriginal() }
        val prefs = mockk<PrefsRepo>()
        every { prefs.hasCookie() } returns true
        setField(service, "hiltInjected", true)
        setField(service, "prefsRepo", prefs)
        setField(service, "userApi", mockk<UserApi>())
        setField(service, "syncServiceState", mockk<SyncServiceState>())
        val caller = Thread {
            runBlocking(main) {
                mainThread.set(Thread.currentThread())
                service.onStartJob(null)
                returned.countDown()
            }
        }
        try {
            caller.start()
            assertTrue("Billing client construction did not start", building.await(5, TimeUnit.SECONDS))
            assertTrue("Job callback blocked on billing initialization", returned.await(1, TimeUnit.SECONDS))
            assertNotSame(mainThread.get(), buildThread.get())
            releaseBuild.countDown()
            assertTrue("Billing connection was not started", connected.await(5, TimeUnit.SECONDS))
            assertSame("Billing connection must start on main", mainThread.get(), connectionThread.get())
        } finally {
            releaseBuild.countDown()
            caller.join(5000)
            assertFalse(caller.isAlive)
            Dispatchers.resetMain()
            main.close()
            unmockkAll()
        }
    }

    private fun setField(service: SubscriptionSyncService, name: String, value: Any) {
        // SubscriptionSyncService.kt runs its real job callback without an Android service host.
        SubscriptionSyncService::class.java.getDeclaredField(name)
            .apply { isAccessible = true }.set(service, value)
    }
}
