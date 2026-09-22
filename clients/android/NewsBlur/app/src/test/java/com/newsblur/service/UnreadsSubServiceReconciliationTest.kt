package com.newsblur.service

import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.text.TextUtils
import com.newsblur.database.ClusterReadStore
import com.newsblur.domain.Story
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
import io.mockk.spyk
import io.mockk.unmockkStatic
import io.mockk.verify
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.function.Predicate

class UnreadsSubServiceReconciliationTest {
    @Before fun setUp() {
        UnreadsSubService.clear()
        mockkStatic(Log::class, TextUtils::class)
        every { Log.i(any<Any>(), any()) } just runs
        every { TextUtils.split(any<String>(), ":") } answers { firstArg<String>().split(':').toTypedArray() }
    }

    @After fun tearDown() {
        UnreadsSubService.clear()
        unmockkStatic(Log::class, TextUtils::class)
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

    @Test fun standaloneRetirementAlsoExcludesCappedOrphanAndDisabledFeeds() = runTest {
        val delegate = mockk<SyncServiceDelegate>(relaxed = true)
        val dbHelper = delegate.dbHelper
        val storyApi = delegate.storyApi
        coEvery { storyApi.getUnreadStoryHashes() } returns UnreadStoryHashesResponse().apply {
            unreadHashes = mapOf(
                "2" to listOf(arrayOf("2:still-unread", "100")),
                "3" to (1..500).map { arrayOf("3:newer-$it", "100") },
                "4" to listOf(arrayOf("4:orphan", "100")),
                "5" to listOf(arrayOf("5:disabled", "100")),
            )
        }
        every { dbHelper.getUnreadStoryHashesAsSet() } returns mutableSetOf(
            "2:retire", "2:still-unread", "3:older-capped", "4:orphan", "5:disabled",
        )
        every { delegate.prefsRepo.getDefaultStoryOrder() } returns StoryOrder.NEWEST
        every { delegate.prefsRepo.isOfflineEnabled() } returns false
        every { delegate.prefsRepo.isEnableNotifications() } returns false
        every { delegate.isOrphanFeed("4") } returns true
        every { delegate.isDisabledFeed("5") } returns true
        val service = UnreadsSubService(delegate)
        service.doMetadata()

        service.launchIn(this).join()

        val retired = slot<Collection<String>>()
        verify(exactly = 1) { dbHelper.markStoryHashesRead(capture(retired), any()) }
        assertEquals(setOf("2:retire"), retired.captured.toSet())
        coVerify(exactly = 0) { storyApi.getStoriesByHash(any()) }
    }

    @Test fun cappedFeedResponseDoesNotRetireAnOmittedEmbeddedUnreadChild() = runTest {
        // apps/reader/models.py returns only 500 hashes even when this feed has 501 unread stories.
        assertFalse(reconcileOmittedEmbeddedChild(this, returnedUnreadCount = 500))
    }

    @Test fun completeFeedResponseCanRetireAnOmittedEmbeddedUnreadChild() = runTest {
        assertTrue(reconcileOmittedEmbeddedChild(this, returnedUnreadCount = 499))
    }

    private suspend fun reconcileOmittedEmbeddedChild(scope: CoroutineScope, returnedUnreadCount: Int): Boolean {
        val omittedHash = "2:older-embedded-child"
        var embedded = arrayOf(Story.ClusterStory().apply { storyHash = omittedHash; feedId = "2"; read = false })
        val database = mockk<SQLiteDatabase>()
        val store = spyk(ClusterReadStore(database))
        every { database.rawQuery(any(), any()) } answers {
            val values = if (firstArg<String>().startsWith("SELECT DISTINCT m.child_hash")) listOf(omittedHash) else emptyList()
            var position = -1
            mockk<Cursor>(relaxed = true).also { cursor ->
                every { cursor.moveToNext() } answers { ++position < values.size }
                every { cursor.getString(0) } answers { values[position] }
                every { cursor.isNull(1) } returns true
            }
        }
        every { store.parentsReferencing(any()) } answers {
            if (omittedHash in firstArg<Set<String>>()) mapOf("1:parent" to embedded) else emptyMap()
        }
        every { store.storedStory(any()) } returns null
        every { store.localReadState(any()) } returns null
        every { store.localReadChangedAt(any()) } returns null
        every { store.pendingReadStateHashes() } returns emptySet()
        every { store.setLocalReadState(any(), any(), any()) } just runs
        every { store.setStoredReadState(any(), any()) } just runs
        every { store.setParentClusters("1:parent", any()) } answers { embedded = secondArg() }

        val delegate = mockk<SyncServiceDelegate>(relaxed = true)
        val dbHelper = delegate.dbHelper
        val storyApi = delegate.storyApi
        coEvery { storyApi.getUnreadStoryHashes() } returns UnreadStoryHashesResponse().apply {
            unreadHashes = mapOf("2" to (1..returnedUnreadCount).map { arrayOf("2:newer-$it", "100") })
        }
        every { dbHelper.getUnreadStoryHashesAsSet() } returns mutableSetOf()
        every { dbHelper.reconcileServerUnreadHashes(any(), any(), any()) } answers {
            store.reconcileServerUnread(firstArg(), secondArg(), thirdArg())
        }
        every { delegate.prefsRepo.getDefaultStoryOrder() } returns StoryOrder.NEWEST
        every { delegate.prefsRepo.isOfflineEnabled() } returns false
        every { delegate.prefsRepo.isEnableNotifications() } returns false
        val service = UnreadsSubService(delegate)
        service.doMetadata()

        service.launchIn(scope).join()

        coVerify(exactly = 0) { storyApi.getStoriesByHash(any()) }
        return embedded[0].read
    }
}
