package com.newsblur.database

import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.text.TextUtils
import com.newsblur.domain.Story
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.runs
import io.mockk.spyk
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.function.BiPredicate
import java.util.function.Predicate

class ClusterUnreadRetirementTest {
    @Before fun setUp() {
        mockkStatic(TextUtils::class)
        every { TextUtils.split(any<String>(), ":") } answers { firstArg<String>().split(':').toTypedArray() }
    }

    @After fun tearDown() = unmockkStatic(TextUtils::class)

    @Test fun remoteReadRetiresAnEmbeddedOnlyUnreadChild() {
        val hash = "2:embedded"
        val db = mockk<SQLiteDatabase>()
        val store = spyk(ClusterReadStore(db))
        every { db.rawQuery(any(), any()) } answers {
            val values = if (firstArg<String>().startsWith("SELECT DISTINCT m.child_hash")) listOf(hash) else emptyList()
            var position = -1
            mockk<Cursor>(relaxed = true).also { cursor ->
                every { cursor.moveToNext() } answers { ++position < values.size }
                every { cursor.getString(0) } answers { values[position] }
                every { cursor.getString(1) } returns "2"
                every { cursor.getLong(2) } returns 100L
            }
        }
        every { store.parentsReferencing(any()) } returns mapOf(
            "1:parent" to arrayOf(Story.ClusterStory().apply { storyHash = hash; feedId = "2"; read = false }),
        )
        every { store.reconcileServerReadState(any(), any(), any()) } just runs

        // UnreadsSubService.kt receives no unread hashes after another device marks this child read.
        store.reconcileServerUnread(emptyList(), 200L)

        verify(exactly = 1) { store.reconcileServerReadState(setOf(hash), true, 200L) }
    }

    @Test fun remoteReadUnreadReadCycleUpdatesEveryEmbeddedCopyWithoutPersistingUncachedHashes() {
        val fixture = Fixture()
        fixture.addChild("2:embedded", true)
        fixture.parents["3:parent"] = arrayOf(child("2:embedded", true))
        val serverUnread = listOf("2:embedded") + (1..1000).map { "4:uncached-$it" }

        fixture.store.reconcileServerUnread(serverUnread, 100L)

        assertFalse(fixture.parents.values.any { it[0].read })
        assertEquals(mapOf("2:embedded" to false), fixture.receipts)

        val nextRequest = fixture.changedAt.getValue("2:embedded") + 1
        fixture.store.reconcileServerUnread(emptyList(), nextRequest)

        assertTrue(fixture.parents.values.all { it[0].read })
        assertEquals(mapOf("2:embedded" to true), fixture.receipts)
        verify(exactly = 0) { fixture.store.adjustCounts(any(), any()) }
    }

    @Test fun unreadChildWithoutAnyReceiptIsRetiredWhenAbsentFromServerUnreadList() {
        val fixture = Fixture()
        fixture.addChild("2:embedded", false)

        fixture.store.reconcileServerUnread(emptyList(), 200L)

        assertTrue(fixture.parents.getValue("1:parent")[0].read)
        assertEquals(true, fixture.receipts["2:embedded"])
    }

    @Test fun serverListedChildKeepsItsUnreadReceipt() {
        val fixture = Fixture()
        fixture.addChild("2:embedded", false)
        fixture.receipts["2:embedded"] = false
        fixture.changedAt["2:embedded"] = 50L

        fixture.store.reconcileServerUnread(listOf("2:embedded"), 200L)

        assertFalse(fixture.parents.getValue("1:parent")[0].read)
        assertEquals(50L, fixture.changedAt["2:embedded"])
    }

    @Test fun absentOrphanAndDisabledFeedsDoNotRetireTheirEmbeddedUnreadChildren() {
        val fixture = Fixture()
        fixture.parents["1:parent"] = arrayOf(child("2:eligible", false), child("3:orphan", false), child("4:disabled", false))

        fixture.store.reconcileServerUnread(emptyList(), 200L, Predicate { it == "2" })

        assertEquals(listOf(true, false, false), fixture.parents.getValue("1:parent").map { it.read })
        assertEquals(mapOf("2:eligible" to true), fixture.receipts)
    }

    @Test fun ineligibleFeedsAreExcludedBeforeDecodingParentClusters() {
        val fixture = Fixture()
        fixture.parents["1:parent"] = arrayOf(child("2:eligible", false))
        fixture.parents["3:parent"] = arrayOf(child("3:orphan", false))
        fixture.parents["4:parent"] = arrayOf(child("4:disabled", false))
        fixture.parents["5:parent"] = arrayOf(child("5:capped", false))

        fixture.store.reconcileServerUnread(emptyList(), 200L, Predicate { it == "2" })

        verify(exactly = 0) {
            fixture.store.parentsReferencing(match { hashes -> hashes.any { it != "2:eligible" } })
        }
        assertEquals(mapOf("2:eligible" to true), fixture.receipts)
    }

    @Test fun repeatedUnreadRefreshDoesNotDecodeKnownReadEmbeddedChildren() {
        val fixture = Fixture()
        repeat(100) { index ->
            fixture.parents["1:parent-$index"] = arrayOf(child("2:read-$index", true))
        }

        repeat(3) { fixture.store.reconcileServerUnread(emptyList(), 200L) }

        verify(exactly = 0) { fixture.store.parentsReferencing(match { it.isNotEmpty() }) }
        verify(exactly = 0) { fixture.store.pendingReadStateHashes() }
        assertTrue(fixture.receipts.isEmpty())
    }

    @Test fun malformedAndBlankHashFeedIdsAreExcludedBeforeDecodingParentClusters() {
        val fixture = Fixture()
        fixture.parents["1:parent"] = arrayOf(
            child("invalid-hash", false).apply { feedId = "2" },
            child(":blank-feed", false).apply { feedId = "2" },
            child(" :whitespace-feed", false).apply { feedId = "2" },
        )

        val stats = fixture.store.reconcileServerUnread(emptyList(), 200L)

        verify(exactly = 0) { fixture.store.parentsReferencing(match { it.isNotEmpty() }) }
        assertEquals(ClusterReadStore.UnreadReconciliationStats(0, 0), stats)
        assertTrue(fixture.receipts.isEmpty())
    }

    @Test fun reconciliationStatsExcludeKnownReadChildrenAndCountTimestampFilteredCandidates() {
        val fixture = Fixture()
        fixture.parents["1:parent"] = arrayOf(
            child("2:unread", false).apply { timestamp = 2000L },
            child("2:too-old", false).apply { timestamp = 1000L },
            child("2:read-metadata", true),
        )
        fixture.parents["3:parent"] = arrayOf(child("3:excluded", false))

        val stats = fixture.store.reconcileServerUnread(emptyList(), 200L, Predicate { it == "2" },
            BiPredicate { feedId, timestamp -> feedId == "2" && timestamp > 1000L })

        assertEquals(ClusterReadStore.UnreadReconciliationStats(2, 1), stats)
        assertEquals(mapOf("2:unread" to true), fixture.receipts)
        verify(exactly = 0) { fixture.store.parentsReferencing(match { "2:too-old" in it || "2:read-metadata" in it }) }
    }

    @Test fun pendingUnreadActionSurvivesRemoteReadRetirement() {
        val fixture = Fixture()
        fixture.addChild("2:embedded", false)
        fixture.receipts["2:embedded"] = false
        fixture.changedAt["2:embedded"] = 50L
        fixture.pending.add("2:embedded")

        fixture.store.reconcileServerUnread(emptyList(), 200L)

        assertFalse(fixture.parents.getValue("1:parent")[0].read)
        assertEquals(false, fixture.receipts["2:embedded"])
        assertEquals(50L, fixture.changedAt["2:embedded"])
    }

    @Test fun unreadActionAfterRequestStartedSurvivesRemoteReadRetirement() {
        val fixture = Fixture()
        fixture.addChild("2:embedded", false)
        fixture.receipts["2:embedded"] = false
        fixture.changedAt["2:embedded"] = 250L

        fixture.store.reconcileServerUnread(emptyList(), 200L)

        assertFalse(fixture.parents.getValue("1:parent")[0].read)
        assertEquals(false, fixture.receipts["2:embedded"])
        assertEquals(250L, fixture.changedAt["2:embedded"])
    }

    @Test fun readReceiptAndUnreferencedUnreadReceiptDoNotCreateRetirementWork() {
        val fixture = Fixture()
        fixture.addChild("2:embedded", false)
        fixture.receipts.putAll(mapOf("2:embedded" to true, "3:unreferenced" to false))
        fixture.changedAt.putAll(mapOf("2:embedded" to 50L, "3:unreferenced" to 50L))

        fixture.store.reconcileServerUnread(emptyList(), 200L)

        assertEquals(mapOf("2:embedded" to 50L, "3:unreferenced" to 50L), fixture.changedAt)
        verify(exactly = 0) { fixture.store.setLocalReadState(any(), any(), any()) }
    }

    @Test fun unreadReceiptTakesPrecedenceOverStoredReadStateAndEmbeddedMetadata() {
        val fixture = Fixture()
        fixture.addChild("2:embedded", true)
        fixture.receipts["2:embedded"] = false
        fixture.stored["2:embedded"] = true
        fixture.changedAt["2:embedded"] = 50L

        fixture.store.reconcileServerUnread(emptyList(), 200L)

        assertEquals(true, fixture.receipts["2:embedded"])
        assertTrue(fixture.parents.getValue("1:parent")[0].read)
    }

    @Test fun storedReadStateAndReadReceiptTakePrecedenceOverStaleEmbeddedUnreadMetadata() {
        val fixture = Fixture()
        fixture.parents["1:parent"] = arrayOf(child("2:stored-read", false), child("3:receipt-read", false))
        fixture.stored.putAll(mapOf("2:stored-read" to true, "3:receipt-read" to false))
        fixture.receipts["3:receipt-read"] = true

        fixture.store.reconcileServerUnread(emptyList(), 200L)

        verify(exactly = 0) { fixture.store.setLocalReadState(any(), any(), any()) }
    }

    @Test fun missingOrBlankChildFeedMetadataIsNotPassedToEligibilityPredicate() {
        val fixture = Fixture()
        fixture.parents["1:parent"] = arrayOf(
            child("2:missing-feed", false).apply { feedId = null },
            child("3:blank-feed", false).apply { feedId = " " },
        )
        val eligibility = mockk<Predicate<String>>()
        every { eligibility.test(any()) } returns true

        fixture.store.reconcileServerUnread(emptyList(), 200L, eligibility)

        verify(exactly = 0) { eligibility.test(match { it.isBlank() }) }
        verify(exactly = 0) { fixture.store.setLocalReadState(any(), any(), any()) }
    }

    // ClusterUnreadRetirementTest.kt exercises store selection plus real repository reconciliation and its guards.
    private class Fixture {
        private val db = mockk<SQLiteDatabase>()
        val store = spyk(ClusterReadStore(db))
        val parents = mutableMapOf<String, Array<Story.ClusterStory>>()
        val receipts = mutableMapOf<String, Boolean>()
        val stored = mutableMapOf<String, Boolean>()
        val changedAt = mutableMapOf<String, Long>()
        val pending = mutableSetOf<String>()

        init {
            every { db.rawQuery(any(), any()) } answers {
                val sql = firstArg<String>()
                val requested = secondArg<Array<String>?>().orEmpty().toSet()
                val children = parents.values.flatMap { it.toList() }.associateBy { it.storyHash }
                val values = when {
                    sql.startsWith("SELECT DISTINCT m.child_hash") -> children.values.filter {
                        !(receipts[it.storyHash] ?: stored[it.storyHash] ?: (sql.contains("m.child_read") && it.read))
                    }.map { it.storyHash }
                    sql.startsWith("SELECT DISTINCT child_hash") -> children.values.filter { it.read && it.storyHash in requested }.map { it.storyHash }
                    else -> (receipts.filterValues { it }.keys + stored.filterValues { it }.keys).filter { it in requested }
                }
                var position = -1
                mockk<Cursor>(relaxed = true).also { cursor ->
                    every { cursor.moveToNext() } answers { ++position < values.size }
                    every { cursor.getString(0) } answers { values[position] }
                    every { cursor.getString(1) } answers { children[values[position]]?.feedId }
                    every { cursor.getLong(2) } answers { children.getValue(values[position]).timestamp }
                }
            }
            every { store.parentsReferencing(any()) } answers {
                val hashes = firstArg<Set<String>>()
                parents.filterValues { children -> children.any { it.storyHash in hashes } }
            }
            every { store.storedStory(any()) } answers {
                val hash = firstArg<String>()
                stored[hash]?.let { ClusterReadRepository.State(hash.substringBefore(':'), 0, it) }
            }
            every { store.localReadState(any()) } answers { receipts[firstArg()] }
            every { store.localReadChangedAt(any()) } answers { changedAt[firstArg()] }
            every { store.pendingReadStateHashes() } answers { pending.toSet() }
            every { store.setLocalReadState(any(), any(), any()) } answers {
                receipts[firstArg()] = secondArg()
                changedAt[firstArg()] = thirdArg()
            }
            every { store.setStoredReadState(any(), any()) } answers {
                if (firstArg<String>() in stored) stored[firstArg()] = secondArg()
            }
            every { store.setParentClusters(any(), any()) } answers { parents[firstArg()] = secondArg() }
        }

        fun addChild(hash: String, read: Boolean) {
            parents["1:parent"] = arrayOf(child(hash, read))
        }
    }

    companion object {
        private fun child(hash: String, read: Boolean) = Story.ClusterStory().apply {
            storyHash = hash
            feedId = hash.substringBefore(':')
            this.read = read
        }
    }
}
