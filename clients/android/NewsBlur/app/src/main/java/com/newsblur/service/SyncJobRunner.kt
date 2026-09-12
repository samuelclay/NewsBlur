package com.newsblur.service

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

internal class SyncJobRunner {
    private val execution = Mutex()

    fun launchIn(
        scope: CoroutineScope,
        block: suspend CoroutineScope.() -> Unit,
    ): Job =
        scope.launch {
            // SyncService.kt cancels superseded generations, but blocking network/Gson work
            // can still run. Keep the permit until that work and all its children finish.
            execution.withLock {
                coroutineScope(block)
            }
        }
}
