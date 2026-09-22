package com.newsblur.database

import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import com.newsblur.domain.Story
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.runs
import io.mockk.spyk
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.function.Predicate

class ClusterUnreadRetirementTest {
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
                every { cursor.isNull(1) } returns true
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

        fixture.store.reconcileServerUnread(emptyList(), 200L, eligibility)

        verify(exactly = 0) { eligibility.test(any()) }
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
                val children = parents.values.flatMap { it.toList() }.map { it.storyHash }.toSet()
                val values = when {
                    sql.startsWith("SELECT DISTINCT m.child_hash") -> children.filter { (receipts[it] ?: stored[it]) != true }
                    sql.startsWith("SELECT DISTINCT child_hash") -> children.filter { it in requested }
                    else -> (receipts.filterValues { it }.keys + stored.filterValues { it }.keys).filter { it in requested }
                }
                var position = -1
                mockk<Cursor>(relaxed = true).also { cursor ->
                    every { cursor.moveToNext() } answers { ++position < values.size }
                    every { cursor.getString(0) } answers { values[position] }
                    every { cursor.isNull(1) } answers { values[position] !in receipts && values[position] !in stored }
                    every { cursor.getInt(1) } answers { if ((receipts[values[position]] ?: stored[values[position]]) == true) 1 else 0 }
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
