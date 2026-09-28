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
        every { Log.w(any<Any>(), any()) } just runs
        every { Log.d(any<String>(), any()) } just runs
        every { TextUtils.split(any<String>(), ":") } answers { firstArg<String>().split(':').toTypedArray() }
    }

    @After fun tearDown() {
        UnreadsSubService.clear()
        unmockkStatic(Log::class, TextUtils::class)
    }

    @Test fun unauthenticatedUnreadResponseCannotRetireCachedStories() = runTest {
        assertUnusableResponseDoesNotRetire(this, UnreadStoryHashesResponse().apply {
            authenticated = false
            unreadHashes = emptyMap()
        })
    }

    @Test fun erroredUnreadResponseCannotRetireCachedStories() = runTest {
        assertUnusableResponseDoesNotRetire(this, UnreadStoryHashesResponse().apply {
            authenticated = true
            isProtocolError = true
            unreadHashes = emptyMap()
        })
    }

    @Test fun missingUnreadHashesCannotRetireCachedStories() = runTest {
        assertUnusableResponseDoesNotRetire(this, UnreadStoryHashesResponse().apply { authenticated = true })
    }

    private suspend fun assertUnusableResponseDoesNotRetire(scope: CoroutineScope, response: UnreadStoryHashesResponse) {
        val delegate = mockk<SyncServiceDelegate>(relaxed = true)
        val dbHelper = delegate.dbHelper
        val storyApi = delegate.storyApi
        coEvery { storyApi.getUnreadStoryHashes() } returns response
        every { dbHelper.getUnreadStoryTimestamps() } returns mapOf("2:keep-unread" to 100_000L)
        every { dbHelper.getAllActiveFeeds() } returns setOf("2")
        every { delegate.prefsRepo.getDefaultStoryOrder() } returns StoryOrder.NEWEST
        val service = UnreadsSubService(delegate)
        service.doMetadata()

        service.launchIn(scope).join()

        verify(exactly = 0) { dbHelper.reconcileServerUnreadHashes(any(), any(), any(), any()) }
        verify(exactly = 0) { dbHelper.markStoryHashesRead(any(), any()) }
        coVerify(exactly = 0) { storyApi.getStoriesByHash(any()) }
    }

    @Test fun embeddedReconciliationRunsWithoutOfflineOrNotificationsAndExcludesIneligibleFeeds() = runTest {
        val delegate = mockk<SyncServiceDelegate>(relaxed = true)
        val dbHelper = delegate.dbHelper
        val storyApi = delegate.storyApi
        coEvery { storyApi.getUnreadStoryHashes() } returns UnreadStoryHashesResponse().apply {
            authenticated = true
            unreadHashes = mapOf("2" to listOf(arrayOf("2:unread", "100")), "3" to listOf(arrayOf("3:orphan", "100")),
                "4" to listOf(arrayOf("4:disabled", "100")))
        }
        every { dbHelper.getUnreadStoryTimestamps() } returns emptyMap()
        every { dbHelper.getAllActiveFeeds() } returns setOf("2", "3", "4")
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
            dbHelper.reconcileServerUnreadHashes(listOf("2:unread"), any(), capture(eligibility), any())
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
            authenticated = true
            unreadHashes = mapOf(
                "2" to listOf(arrayOf("2:still-unread", "100")),
                "3" to (1..500).map { arrayOf("3:newer-$it", "100") },
                "4" to listOf(arrayOf("4:orphan", "100")),
                "5" to listOf(arrayOf("5:disabled", "100")),
            )
        }
        every { dbHelper.getUnreadStoryTimestamps() } returns listOf(
            "2:retire", "2:still-unread", "3:older-capped", "4:orphan", "5:disabled",
        ).associateWith { 99_000L }
        every { dbHelper.getAllActiveFeeds() } returns setOf("2", "3", "4", "5")
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

    @Test fun unsubscribedFeedCannotRetireItsEmbeddedUnreadChild() = runTest {
        assertFalse(reconcileOmittedEmbeddedChild(this, returnedUnreadCount = 0, activeFeeds = emptySet()))
    }

    @Test fun cappedFeedCanRetireAnOmittedEmbeddedChildNewerThanItsOldestReturnedHash() = runTest {
        assertTrue(reconcileOmittedEmbeddedChild(this, returnedUnreadCount = 500, timestampMillis = 101_000L))
    }

    @Test fun cappedFeedKeepsAnOmittedEmbeddedChildAtTheOldestReturnedTimestamp() = runTest {
        assertFalse(reconcileOmittedEmbeddedChild(this, returnedUnreadCount = 500, timestampMillis = 100_000L))
    }

    @Test fun activeFeedWithNoUnreadHashesCanRetireItsEmbeddedChild() = runTest {
        assertTrue(reconcileOmittedEmbeddedChild(this, returnedUnreadCount = 0))
    }

    @Test fun malformedOrMissingCapTimestampDoesNotRetireAnEmbeddedChild() = runTest {
        for (invalidTimestamp in listOf(null, "bad", "0", "-1", "NaN", "Infinity", "1e100")) {
            assertFalse(reconcileOmittedEmbeddedChild(this, returnedUnreadCount = 500,
                timestampMillis = 101_000L, lastTimestamp = invalidTimestamp))
        }
    }

    @Test fun fractionalSecondCapTimestampPreservesAnExactTieAndRetiresNewerChild() = runTest {
        assertFalse(reconcileOmittedEmbeddedChild(this, returnedUnreadCount = 500,
            timestampMillis = 100_500L, returnedTimestamp = "100.5"))
        assertTrue(reconcileOmittedEmbeddedChild(this, returnedUnreadCount = 500,
            timestampMillis = 100_501L, returnedTimestamp = "100.5"))
    }

    @Test fun capTimestampWithFractionalSecondsCannotRoundBelowAnExactMillisecondTie() = runTest {
        assertFalse(reconcileOmittedEmbeddedChild(this, returnedUnreadCount = 500,
            timestampMillis = 1001L, returnedTimestamp = "1.001"))
        assertFalse(reconcileOmittedEmbeddedChild(this, returnedUnreadCount = 500,
            timestampMillis = 1000L, returnedTimestamp = "1.001"))
        assertTrue(reconcileOmittedEmbeddedChild(this, returnedUnreadCount = 500,
            timestampMillis = 1002L, returnedTimestamp = "1.001"))
    }

    @Test fun cappedStandaloneRetirementUsesStrictTimestampWindowAndKeepsServerListedStories() = runTest {
        val delegate = mockk<SyncServiceDelegate>(relaxed = true)
        val dbHelper = delegate.dbHelper
        val storyApi = delegate.storyApi
        coEvery { storyApi.getUnreadStoryHashes() } returns UnreadStoryHashesResponse().apply {
            authenticated = true
            unreadHashes = mapOf("2" to (1..499).map { arrayOf("2:newer-$it", "100.0") } +
                listOf(arrayOf("2:still-unread", "101.0")))
        }
        every { dbHelper.getUnreadStoryTimestamps() } returns mapOf(
            "2:older" to 99_000L, "2:tie" to 100_000L, "2:newer" to 100_001L,
            "2:still-unread" to 101_000L, "3:uncapped" to 0L,
        )
        every { dbHelper.getAllActiveFeeds() } returns setOf("2", "3")
        every { delegate.prefsRepo.getDefaultStoryOrder() } returns StoryOrder.NEWEST
        every { delegate.prefsRepo.isOfflineEnabled() } returns false
        every { delegate.prefsRepo.isEnableNotifications() } returns false
        val service = UnreadsSubService(delegate)
        service.doMetadata()

        service.launchIn(this).join()

        val retired = slot<Collection<String>>()
        verify(exactly = 1) { dbHelper.markStoryHashesRead(capture(retired), any()) }
        assertEquals(setOf("2:newer", "3:uncapped"), retired.captured.toSet())
        coVerify(exactly = 0) { storyApi.getStoriesByHash(any()) }
    }

    @Test fun unsubscribedFeedCannotRetireItsStandaloneUnreadStory() = runTest {
        val delegate = mockk<SyncServiceDelegate>(relaxed = true)
        val dbHelper = delegate.dbHelper
        val storyApi = delegate.storyApi
        coEvery { storyApi.getUnreadStoryHashes() } returns UnreadStoryHashesResponse().apply {
            authenticated = true
            unreadHashes = emptyMap()
        }
        every { dbHelper.getUnreadStoryTimestamps() } returns mapOf("2:active" to 99_000L, "6:unsubscribed" to 99_000L)
        every { dbHelper.getAllActiveFeeds() } returns setOf("2")
        every { delegate.prefsRepo.getDefaultStoryOrder() } returns StoryOrder.NEWEST
        val service = UnreadsSubService(delegate)
        service.doMetadata()

        service.launchIn(this).join()

        val retired = slot<Collection<String>>()
        verify(exactly = 1) { dbHelper.markStoryHashesRead(capture(retired), any()) }
        assertEquals(setOf("2:active"), retired.captured.toSet())
    }

    @Test fun cappedFeedResponseDoesNotRetireAnOmittedEmbeddedUnreadChild() = runTest {
        // apps/reader/models.py returns only 500 hashes even when this feed has 501 unread stories.
        assertFalse(reconcileOmittedEmbeddedChild(this, returnedUnreadCount = 500))
    }

    @Test fun completeFeedResponseCanRetireAnOmittedEmbeddedUnreadChild() = runTest {
        assertTrue(reconcileOmittedEmbeddedChild(this, returnedUnreadCount = 499))
    }

    private suspend fun reconcileOmittedEmbeddedChild(
        scope: CoroutineScope,
        returnedUnreadCount: Int,
        timestampMillis: Long = 99_000L,
        activeFeeds: Set<String> = setOf("2"),
        returnedTimestamp: String = "100.0",
        lastTimestamp: String? = returnedTimestamp,
    ): Boolean {
        val omittedHash = "2:older-embedded-child"
        var embedded = arrayOf(Story.ClusterStory().apply {
            storyHash = omittedHash
            feedId = "2"
            read = false
            timestamp = timestampMillis
        })
        val database = mockk<SQLiteDatabase>()
        val store = spyk(ClusterReadStore(database))
        every { database.rawQuery(any(), any()) } answers {
            val values = if (firstArg<String>().startsWith("SELECT DISTINCT m.child_hash")) listOf(omittedHash) else emptyList()
            var position = -1
            mockk<Cursor>(relaxed = true).also { cursor ->
                every { cursor.moveToNext() } answers { ++position < values.size }
                every { cursor.getString(0) } answers { values[position] }
                every { cursor.getString(1) } returns "2"
                every { cursor.getLong(2) } returns timestampMillis
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
            authenticated = true
            unreadHashes = mapOf("2" to (1..returnedUnreadCount).map {
                val timestamp = if (it == returnedUnreadCount) lastTimestamp else returnedTimestamp
                if (timestamp == null) arrayOf("2:newer-$it") else arrayOf("2:newer-$it", timestamp)
            })
        }
        every { dbHelper.getUnreadStoryTimestamps() } returns emptyMap()
        every { dbHelper.getAllActiveFeeds() } returns activeFeeds
        every { dbHelper.reconcileServerUnreadHashes(any(), any(), any(), any()) } answers {
            store.reconcileServerUnread(firstArg(), secondArg(), thirdArg(), arg(3))
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
