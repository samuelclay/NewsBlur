package com.newsblur.service

import com.newsblur.NbApplication.Companion.isAppForeground
import com.newsblur.util.AppConstants
import com.newsblur.util.Log
import com.newsblur.util.NBScope
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
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

    private var cycleStartTime = 0L
    private var mainJob: Job? = null
    private var awaitTerminationJob: Job? = null

    protected abstract fun exec()

    fun start() {
        mainJob = coroutineScope.launch {
            if (!parent.stopSync()) {
                execInternal()
            }

            if (isActive) {
                parent.checkCompletion()
                parent.sendSyncUpdate(NBSyncReceiver.UPDATE_STATUS)
            }
        }.apply {
            invokeOnCompletion {
                awaitTerminationJob?.cancel()
            }
        }
    }

    private suspend fun execInternal() = coroutineScope {
        try {
            ensureActive()
            exec()
            cycleStartTime = 0
        } catch (e: Exception) {
            Log.e(this.javaClass.name, "Sync error.", e)
        }
    }

    fun shutdown() {
        Log.d(this, "SubService shutdown")
        try {
            mainJob?.let { job ->
                if (job.isActive) {
                    awaitTerminationJob = coroutineScope.launch {
                        withTimeout(AppConstants.SHUTDOWN_SLACK_SECONDS) {
                            if (job.isActive) job.cancel()
                        }
                    }
                }
            }
        } catch (e: CancellationException) {
            Log.d(this, "SubService cancelled")
        } finally {
            Log.d(this, "SubService stopped")
        }
    }

    // don't advise completion until there are no tasks, or just one check task left
    val isRunning: Boolean
        get() =// don't advise completion until there are no tasks, or just one check task left
            mainJob?.isActive ?: false

    /**
     * If called at the beginning of an expensive loop in a SubService, enforces the maximum duty cycle
     * defined in AppConstants by sleeping for a short while so the SubService does not dominate system
     * resources.
     */
    protected fun startExpensiveCycle() {
        if (cycleStartTime == 0L) {
            cycleStartTime = System.nanoTime()
            return
        }
        val lastCycleTime = (System.nanoTime() - cycleStartTime).toDouble()
        if (lastCycleTime < 1) return
        cycleStartTime = System.nanoTime()
        val cooloffTime = lastCycleTime * (1.0 - AppConstants.MAX_BG_DUTY_CYCLE)
        if (cooloffTime < 1) return
        var cooloffTimeMs = Math.round(cooloffTime / 1000000.0)
        if (cooloffTimeMs > AppConstants.DUTY_CYCLE_BACKOFF_CAP_MILLIS) cooloffTimeMs = AppConstants.DUTY_CYCLE_BACKOFF_CAP_MILLIS
        if (isAppForeground) {
            Log.d(this.javaClass.name, "Sleeping for : " + cooloffTimeMs + "ms to enforce max duty cycle.")
            try {
                Thread.sleep(cooloffTimeMs)
            } catch (e: InterruptedException) {
                Thread.currentThread().interrupt()
            }
        }
    }
}