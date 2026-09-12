package com.newsblur.service

import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertTrue
import org.junit.Test

class UnreadsSubServiceCancellationTest {
    @Test
    fun canceledUnreadMetadataRemainsPendingForTheNextGeneration() =
        runTest {
            val delegate = mockk<SyncServiceDelegate>(relaxed = true)
            coEvery { delegate.storyApi.getUnreadStoryHashes() } throws CancellationException("new foreground request")
            val service = UnreadsSubService(delegate)
            service.doMetadata()

            service.launchIn(this).join()

            assertTrue("Canceling a generation must not lose its unread-hash refresh", service.isDoMetadata)
        }
}
