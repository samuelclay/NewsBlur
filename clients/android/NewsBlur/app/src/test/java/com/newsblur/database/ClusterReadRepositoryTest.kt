package com.newsblur.database

import com.newsblur.domain.Story
import org.junit.Assert.*
import org.junit.Test

class ClusterReadRepositoryTest {
    private val backend = MemoryBackend()
    private val repository = ClusterReadRepository(backend)

    @Test fun updatesLoadedAndEmbeddedOnlyChildrenAcrossAllParentsOnce() {
        backend.stories["2:loaded"] = ClusterReadRepository.State("2", 1, false)
        backend.parents["1:parent"] = arrayOf(child("2:loaded", 1), child("3:embedded", 0))
        backend.parents["4:parent"] = arrayOf(child("3:embedded", 0))

        repository.apply(listOf("2:loaded", "3:embedded", "3:embedded"), true, true)
        repository.apply(listOf("2:loaded", "3:embedded"), true, true)

        assertTrue(backend.stories.getValue("2:loaded").read)
        assertTrue(backend.parents.values.flatMap { it.toList() }.all { it.read })
        assertEquals(listOf("2:1:-1", "3:0:-1"), backend.countChanges)
    }

    @Test fun alreadyReadStoredChildOverridesStaleUnreadEmbeddedCopies() {
        backend.stories["2:loaded"] = ClusterReadRepository.State("2", 0, true)
        backend.parents["1:parent"] = arrayOf(child("2:loaded", 0))
        repository.apply(listOf("2:loaded"), true, true)
        assertTrue(backend.parents.getValue("1:parent")[0].read)
        assertTrue(backend.countChanges.isEmpty())
    }

    @Test fun conflictingEmbeddedCopiesDoNotDecrementAChildAlreadyKnownRead() {
        backend.parents["1:parent"] = arrayOf(child("2:child", 0).apply { read = true })
        backend.parents["3:parent"] = arrayOf(child("2:child", 0))
        repository.apply(listOf("2:child"), true, true)
        assertTrue(backend.parents.values.all { it[0].read })
        assertTrue(backend.countChanges.isEmpty())
    }

    @Test fun unknownAuthoritativeHashIsRememberedWithoutGuessingItsIntelligenceCount() {
        repository.apply(listOf("8:unloaded"), true, true)
        assertEquals(true, backend.overrides["8:unloaded"])
        assertTrue(backend.countChanges.isEmpty())
    }

    @Test fun manualUnreadUpdatesAllCopiesAndAllowsTheNextReadToDecrementAgain() {
        backend.parents["1:parent"] = arrayOf(child("2:child", 0))
        repository.apply(listOf("2:child"), true, true)
        repository.apply(listOf("2:child"), false, true)
        assertFalse(backend.parents.getValue("1:parent")[0].read)
        repository.apply(listOf("2:child"), true, true)
        assertEquals(listOf("2:0:-1", "2:0:1", "2:0:-1"), backend.countChanges)
    }

    @Test fun followupReplayRepairsMetadataWithoutDecrementingRefreshedCounts() {
        backend.parents["1:parent"] = arrayOf(child("2:child", 0))
        repository.apply(listOf("2:child"), true, false)
        assertTrue(backend.parents.getValue("1:parent")[0].read)
        assertTrue(backend.countChanges.isEmpty())
    }

    @Test fun changingReadMetadataDoesNotMutatePublishedParentArray() {
        val original = arrayOf(child("2:child", 0))
        backend.parents["1:parent"] = original
        repository.apply(listOf("2:child"), true, true)
        assertFalse(original[0].read)
        assertTrue(backend.parents.getValue("1:parent")[0].read)
    }

    @Test fun serverReadRetirementReplacesOlderManualUnreadReceiptAndEmbeddedCopies() {
        backend.parents["1:parent"] = arrayOf(child("2:child", 0))
        backend.overrides["2:child"] = false
        backend.changedAt["2:child"] = 50
        repository.reconcileServerReadState(listOf("2:child"), true, 100)
        assertEquals(true, backend.overrides["2:child"])
        assertTrue(backend.parents.getValue("1:parent")[0].read)
        assertTrue(backend.countChanges.isEmpty())
    }

    @Test fun bulkReadSupersedesManualUnreadReceiptsAndEmbeddedCopiesWithoutCountDeltas() {
        backend.stories["2:child"] = ClusterReadRepository.State("2", 0, false)
        backend.parents["1:parent"] = arrayOf(child("2:child", 0))
        backend.overrides["2:child"] = false
        repository.applyBulkRead(listOf("2:child"))
        assertEquals(true, backend.overrides["2:child"])
        assertTrue(backend.parents.getValue("1:parent")[0].read)
        assertTrue(backend.countChanges.isEmpty())
    }

    @Test fun olderReadResponseCannotOverwriteNewerUnreadButStillAppliesOtherExpandedChildren() {
        backend.parents["1:parent"] = arrayOf(child("2:newer-unread", 0), child("3:expanded", 1))
        backend.overrides["2:newer-unread"] = false
        backend.changedAt["2:newer-unread"] = 200
        repository.apply(listOf("2:newer-unread", "3:expanded"), true, true, 100)
        assertEquals(false, backend.overrides["2:newer-unread"])
        assertFalse(backend.parents.getValue("1:parent")[0].read)
        assertTrue(backend.parents.getValue("1:parent")[1].read)
        assertEquals(listOf("3:1:-1"), backend.countChanges)
    }

    @Test fun serverUnreadRefreshRestoresOlderReadButCannotUndoReadDuringRequest() {
        backend.parents["1:parent"] = arrayOf(child("2:older", 0).apply { read = true }, child("3:newer", 0).apply { read = true })
        backend.overrides.putAll(mapOf("2:older" to true, "3:newer" to true))
        backend.changedAt.putAll(mapOf("2:older" to 50, "3:newer" to 150))
        repository.reconcileServerReadState(listOf("2:older", "3:newer"), false, 100)
        assertFalse(backend.parents.getValue("1:parent")[0].read)
        assertTrue(backend.parents.getValue("1:parent")[1].read)
        assertEquals(false, backend.overrides["2:older"])
        assertEquals(true, backend.overrides["3:newer"])
        assertTrue(backend.countChanges.isEmpty())
    }

    @Test fun unreadRefreshCannotUndoAnOlderOfflineReadStillQueuedForDelivery() {
        backend.parents["1:parent"] = arrayOf(child("2:child", 0).apply { read = true })
        backend.overrides["2:child"] = true
        backend.changedAt["2:child"] = 50
        backend.pending.add("2:child")
        repository.reconcileServerReadState(listOf("2:child"), false, 100)
        assertTrue(backend.parents.getValue("1:parent")[0].read)
        assertEquals(true, backend.overrides["2:child"])
    }

    private fun child(hash: String, scoreValue: Int) = Story.ClusterStory().apply {
        storyHash = hash
        feedId = hash.substringBefore(':')
        score = scoreValue
    }

    private class MemoryBackend : ClusterReadRepository.Backend {
        val stories = mutableMapOf<String, ClusterReadRepository.State>()
        val parents = mutableMapOf<String, Array<Story.ClusterStory>>()
        val overrides = mutableMapOf<String, Boolean>()
        val changedAt = mutableMapOf<String, Long>()
        val pending = mutableSetOf<String>()
        val countChanges = mutableListOf<String>()
        override fun storedStory(hash: String) = stories[hash]
        override fun localReadState(hash: String) = overrides[hash]
        override fun localReadChangedAt(hash: String) = changedAt[hash]
        override fun pendingReadStateHashes() = pending
        override fun parentsReferencing(hashes: Set<String>) = parents.filterValues { children -> children.any { it.storyHash in hashes } }
        override fun setLocalReadState(hash: String, read: Boolean) { overrides[hash] = read }
        override fun setStoredReadState(hash: String, read: Boolean) { stories[hash]?.let { stories[hash] = it.copy(read = read) } }
        override fun setParentClusters(hash: String, children: Array<Story.ClusterStory>) { parents[hash] = children }
        override fun adjustCounts(state: ClusterReadRepository.State, delta: Int) { countChanges.add("${state.feedId}:${state.score}:$delta") }
    }
}
