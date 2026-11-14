package com.newsblur.preference

import com.newsblur.network.UserApi
import com.newsblur.util.PrefConstants
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/** ClusterMarkReadPreference.kt keeps optimistic local changes in the same order as server saves. */
internal class ClusterMarkReadPreference(
    private val prefsRepo: PrefsRepo,
    private val userApi: UserApi,
) {
    private val saveLock = Mutex()

    // ClusterMarkReadPreference.kt finishes the save or rollback even when the settings screen closes.
    suspend fun setEnabled(enabled: Boolean): Boolean = withContext(NonCancellable) {
        saveLock.withLock {
            val previous = prefsRepo.getBoolean(PrefConstants.CLUSTER_MARK_READ, false)
            if (previous == enabled) return@withLock true
            prefsRepo.putBoolean(PrefConstants.CLUSTER_MARK_READ, enabled)
            val saved = try {
                userApi.setPreference(PrefConstants.CLUSTER_MARK_READ, enabled.toString())
            } catch (error: CancellationException) {
                prefsRepo.putBoolean(PrefConstants.CLUSTER_MARK_READ, previous)
                throw error
            } catch (_: Exception) {
                false
            }
            prefsRepo.putBoolean(PrefConstants.CLUSTER_MARK_READ, if (saved) enabled else previous)
            saved
        }
    }
}
