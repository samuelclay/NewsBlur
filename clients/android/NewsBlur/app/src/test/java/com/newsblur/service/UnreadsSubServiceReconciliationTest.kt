package com.newsblur.service

import com.newsblur.network.domain.UnreadStoryHashesResponse
import com.newsblur.util.Log
import com.newsblur.util.StoryOrder
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.runs
import io.mockk.slot
import io.mockk.unmockkStatic
import io.mockk.verify
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.function.Predicate

class UnreadsSubServiceReconciliationTest {
    @Before fun setUp() {
        UnreadsSubService.clear()
        mockkStatic(Log::class)
        every { Log.i(any<Any>(), any()) } just runs
    }

    @After fun tearDown() {
        UnreadsSubService.clear()
        unmockkStatic(Log::class)
    }

    @Test fun embeddedReconciliationRunsWithoutOfflineOrNotificationsAndExcludesIneligibleFeeds() = runTest {
        val delegate = mockk<SyncServiceDelegate>(relaxed = true)
        val dbHelper = delegate.dbHelper
        val storyApi = delegate.storyApi
        coEvery { storyApi.getUnreadStoryHashes() } returns UnreadStoryHashesResponse().apply {
            unreadHashes = mapOf("2" to listOf(arrayOf("2:unread", "100")), "3" to listOf(arrayOf("3:orphan", "100")),
                "4" to listOf(arrayOf("4:disabled", "100")))
        }
        every { dbHelper.getUnreadStoryHashesAsSet() } returns mutableSetOf()
        every { delegate.prefsRepo.getDefaultStoryOrder() } returns StoryOrder.NEWEST
        every { delegate.prefsRepo.isOfflineEnabled() } returns false
        every { delegate.prefsRepo.isEnableNotifications() } returns false
        every { delegate.isOrphanFeed("3") } returns true
        every { delegate.isDisabledFeed("4") } returns true
        val service = UnreadsSubService(delegate)
        service.doMetadata()

        service.launchIn(this).join()

        val eligibility = slot<Predicate<String>>()
        verify(exactly = 1) {
            dbHelper.reconcileServerUnreadHashes(listOf("2:unread"), any(), capture(eligibility))
        }
        assertTrue(eligibility.captured.test("2"))
        assertFalse(eligibility.captured.test("3"))
        assertFalse(eligibility.captured.test("4"))
        coVerify(exactly = 0) { storyApi.getStoriesByHash(any()) }
    }
}
