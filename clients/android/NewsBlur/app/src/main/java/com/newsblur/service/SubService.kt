package com.newsblur.service

import com.newsblur.util.Log
import com.newsblur.util.NBScope
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.util.concurrent.CancellationException

/**
 * A utility construct to make NbSyncService a bit more modular by encapsulating sync tasks
 * that can be run fully asynchronously from the main sync loop.  Like all of the sync service,
 * flags and data used by these modules need to be static so that parts of the app without a
 * handle to the service object can access them.
 */
abstract class SubService(
        @JvmField
        protected val parent: NBSyncService,
        private val coroutineScope: CoroutineScope = NBScope,
) {

    private var mainJob: Job? = null

    protected abstract fun exec()

    fun start() {
        mainJob = coroutineScope.launch(Dispatchers.IO) {
            if (parent.stopSync()) return@launch

            Thread.currentThread().name = this@SubService.javaClass.name
            execInternal()

            if (isActive) {
                parent.checkCompletion()
                parent.sendSyncUpdate(NbSyncManager.UPDATE_STATUS)
            }
        }
    }

    private suspend fun execInternal() = coroutineScope {
        try {
            ensureActive()
            exec()
        } catch (e: Exception) {
            Log.e(this@SubService.javaClass.name, "Sync error.", e)
        }
    }

    fun shutdown() {
        Log.d(this, "SubService shutdown")
        try {
            mainJob?.cancel()
        } catch (e: CancellationException) {
            Log.d(this, "SubService cancelled")
        } finally {
            Log.d(this, "SubService stopped")
        }
    }

    val isRunning: Boolean
        get() = mainJob?.isActive ?: false
}