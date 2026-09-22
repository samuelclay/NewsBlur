package com.newsblur.preference

import com.newsblur.network.UserApi
import com.newsblur.util.PrefConstants
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ClusterMarkReadSaveTest {
    private var enabled = false
    private val prefsRepo = mockk<PrefsRepo> {
        every { getBoolean(PrefConstants.CLUSTER_MARK_READ, false) } answers { enabled }
        every { putBoolean(PrefConstants.CLUSTER_MARK_READ, any()) } answers { enabled = secondArg() }
    }
    private val userApi = mockk<UserApi>()

    @Test fun failedSaveRollsBackTheVisiblePreference() = runTest {
        coEvery { userApi.setPreference(PrefConstants.CLUSTER_MARK_READ, "true") } returns false
        assertFalse(ClusterMarkReadPreference(prefsRepo, userApi).setEnabled(true))
        assertFalse(enabled)
    }

    @Test fun thrownSaveRollsBackTheVisiblePreference() = runTest {
        coEvery { userApi.setPreference(PrefConstants.CLUSTER_MARK_READ, "true") } throws java.io.IOException("offline")
        assertFalse(ClusterMarkReadPreference(prefsRepo, userApi).setEnabled(true))
        assertFalse(enabled)
    }

    @Test fun fastChangesSaveInOrderAndKeepTheLatestState() = runTest {
        val firstSaved = CompletableDeferred<Boolean>()
        coEvery { userApi.setPreference(PrefConstants.CLUSTER_MARK_READ, "true") } coAnswers { firstSaved.await() }
        coEvery { userApi.setPreference(PrefConstants.CLUSTER_MARK_READ, "false") } returns true
        val preference = ClusterMarkReadPreference(prefsRepo, userApi)
        launch { assertTrue(preference.setEnabled(true)) }
        runCurrent()
        assertTrue(enabled)
        launch { assertTrue(preference.setEnabled(false)) }
        runCurrent()
        coVerify(exactly = 0) { userApi.setPreference(PrefConstants.CLUSTER_MARK_READ, "false") }
        firstSaved.complete(true)
        runCurrent()
        assertFalse(enabled)
        coVerify(exactly = 1) { userApi.setPreference(PrefConstants.CLUSTER_MARK_READ, "true") }
        coVerify(exactly = 1) { userApi.setPreference(PrefConstants.CLUSTER_MARK_READ, "false") }
    }
}
