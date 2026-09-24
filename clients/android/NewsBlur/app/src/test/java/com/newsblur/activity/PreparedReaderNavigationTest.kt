package com.newsblur.activity

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PreparedReaderNavigationTest {
    @Test
    fun outgoingPageRemainsUntilCaptureThenTheMatchingPageIsReady() {
        val fixture = Fixture()
        fixture.navigation.request(page(0), page(20))
        assertTrue(fixture.prepared.isEmpty())
        assertTrue(fixture.committed.isEmpty())
        fixture.captures.single()(true)
        assertEquals(listOf(page(20)), fixture.prepared)
        fixture.navigation.ready(page(1).storyHash)
        assertTrue(fixture.committed.isEmpty())
        assertEquals(0, fixture.releases)
        fixture.navigation.ready(page(20).storyHash)
        assertEquals(listOf(page(20)), fixture.committed)
        assertEquals(listOf(1), fixture.directions)
        assertEquals(0, fixture.releases)
        fixture.animations.single()()
        assertEquals(1, fixture.releases)
        assertFalse(fixture.navigation.isActive)
    }

    @Test
    fun rapidRequestsDuringCaptureKeepOneSnapshotAndPrepareOnlyTheLatestTarget() {
        val fixture = Fixture()
        fixture.navigation.request(page(0), page(20))
        fixture.navigation.request(page(0), page(30))
        fixture.navigation.request(page(0), page(40))
        assertEquals(1, fixture.captures.size)
        fixture.captures.single()(true)
        assertEquals(listOf(page(40)), fixture.prepared)
    }

    @Test
    fun staleReadyCallbacksCannotRevealOrMarkAnAbandonedTargetRead() {
        val fixture = Fixture()
        fixture.navigation.request(page(0), page(20))
        fixture.captures.single()(true)
        fixture.navigation.request(page(20), page(30))
        fixture.navigation.ready(page(20).storyHash)
        assertTrue(fixture.committed.isEmpty())
        fixture.navigation.ready(page(30).storyHash)
        assertEquals(listOf(page(30)), fixture.committed)
        assertEquals(1, fixture.captures.size)
    }

    @Test
    fun previousAnimatesInTheReverseDirectionAndPreservesItsHistoryIntent() {
        val fixture = Fixture()
        val previous = page(3).copy(isHistoryBack = true)
        fixture.navigation.request(page(20), previous)
        fixture.captures.single()(true)
        assertTrue(fixture.committed.isEmpty())
        fixture.navigation.ready(previous.storyHash)
        assertEquals(listOf(previous), fixture.committed)
        assertEquals(listOf(-1), fixture.directions)
    }

    @Test
    fun backDuringCaptureDisarmsItsCallback() {
        val fixture = Fixture()
        fixture.navigation.request(page(0), page(20))
        fixture.navigation.cancel()
        fixture.captures.single()(true)
        assertTrue(fixture.prepared.isEmpty())
        assertTrue(fixture.committed.isEmpty())
        assertEquals(1, fixture.releases)
    }

    @Test
    fun committedBackKeepsOutgoingPixelsUntilTheExitAnimationCompletes() {
        val fixture = Fixture()
        fixture.navigation.request(page(0), page(20))
        fixture.captures.single()(true)
        fixture.navigation.cancel(releaseSnapshot = false)
        fixture.navigation.ready(page(20).storyHash)
        assertTrue(fixture.committed.isEmpty())
        assertEquals(0, fixture.releases)
        assertFalse(fixture.navigation.isActive)
    }

    @Test
    fun requestsDuringAnimationQueueOnlyTheLatestDestination() {
        val fixture = Fixture()
        fixture.navigation.request(page(0), page(20))
        fixture.captures.single()(true)
        fixture.navigation.ready(page(20).storyHash)
        fixture.navigation.request(page(20), page(30))
        fixture.navigation.request(page(20), page(40))
        assertEquals(1, fixture.captures.size)
        fixture.animations.single()()
        assertEquals(2, fixture.captures.size)
        fixture.captures.last()(true)
        assertEquals(listOf(page(20), page(40)), fixture.prepared)
        fixture.navigation.ready(page(40).storyHash)
        assertEquals(listOf(page(20), page(40)), fixture.committed)
    }

    @Test
    fun failedCaptureKeepsTheExistingPageAndDoesNotCommitTheDestination() {
        val fixture = Fixture()
        fixture.navigation.request(page(0), page(20))
        fixture.captures.single()(false)
        assertTrue(fixture.prepared.isEmpty())
        assertTrue(fixture.committed.isEmpty())
        assertEquals(1, fixture.failures)
        assertFalse(fixture.navigation.isActive)
    }

    @Test
    fun repeatedReadyCallbacksCommitAndAnimateOnlyOnce() {
        val fixture = Fixture()
        fixture.navigation.request(page(0), page(20))
        fixture.captures.single()(true)
        repeat(3) { fixture.navigation.ready(page(20).storyHash) }
        assertEquals(listOf(page(20)), fixture.committed)
        assertEquals(listOf(1), fixture.directions)
    }

    @Test
    fun backgroundingWhilePreparingRetainsOutgoingPixelsAndDefersCommitUntilResume() {
        val fixture = Fixture()
        fixture.navigation.request(page(0), page(20))
        fixture.captures.single()(true)
        fixture.navigation.pause()
        fixture.navigation.ready(page(20).storyHash)
        assertTrue(fixture.committed.isEmpty())
        assertEquals(0, fixture.releases)
        fixture.navigation.resume()
        assertEquals(listOf(page(20), page(20)), fixture.prepared)
        fixture.navigation.ready(page(20).storyHash)
        assertEquals(listOf(page(20)), fixture.committed)
    }

    @Test
    fun captureFinishingInTheBackgroundDoesNotSwitchThePagerUntilResume() {
        val fixture = Fixture()
        fixture.navigation.request(page(0), page(20))
        fixture.navigation.pause()
        fixture.captures.single()(true)
        assertTrue(fixture.prepared.isEmpty())
        assertEquals(0, fixture.releases)
        fixture.navigation.resume()
        assertEquals(listOf(page(20)), fixture.prepared)
    }

    @Test
    fun canceledBackgroundPreparationCannotRestartOnResume() {
        val fixture = Fixture()
        fixture.navigation.request(page(0), page(20))
        fixture.navigation.pause()
        fixture.navigation.cancel()
        fixture.captures.single()(true)
        fixture.navigation.resume()
        fixture.navigation.ready(page(20).storyHash)
        assertTrue(fixture.prepared.isEmpty())
        assertTrue(fixture.committed.isEmpty())
    }

    private fun page(position: Int) = ReaderPageTarget("1:$position", position)

    private class Fixture {
        val captures = mutableListOf<(Boolean) -> Unit>()
        val prepared = mutableListOf<ReaderPageTarget>()
        val committed = mutableListOf<ReaderPageTarget>()
        val directions = mutableListOf<Int>()
        val animations = mutableListOf<() -> Unit>()
        var releases = 0
        var failures = 0
        val navigation = PreparedReaderNavigation(
            capture = captures::add,
            prepare = prepared::add,
            commit = committed::add,
            animate = { direction, completion -> directions.add(direction); animations.add(completion) },
            release = { releases++ },
            captureFailed = { failures++ },
        )
    }
}
